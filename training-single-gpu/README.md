# Training a model with GPUs on GKE 

## Setup steps

1. Preliminary steps

    * Project, billing, APIs, ...

## Create GKE Cluster and GPU Nodepools

1. Create Standard cluster WITH workoad identify AND addons

    ```bash
    PROJECT_ID=<project-id>
    REGION=<region>
    CLUSTER_NAME=<cluster_name>

    gcloud beta container clusters create ${CLUSTER_NAME} \
        --addons GcsFuseCsiDriver \
        --region=${REGION} \
        --workload-pool=${PROJECT_ID}.svc.id.goog \
        --release-channel=rapid 
    ```

2. (Optional) Enable GcsFuseCsiDriver addon in an existing cluster

    ```bash
    gcloud beta container clusters update ${CLUSTER_NAME} \
        --update-addons GcsFuseCsiDriver=ENABLED \
        --region=${REGION}
    ```

3. Create GPU nodepool
    ```bash
    gcloud container node-pools create gpu-pool \
        --accelerator type=nvidia-tesla-t4,count=1 \
        --region ${REGION} --cluster ${CLUSTER_NAME} \
        --machine-type n1-standard-16 --num-nodes 1
    ```

4. (Required for GKE version < 1.27.2-gke.1200) Install CUDA drivers. [Reference](https://cloud.google.com/kubernetes-engine/docs/how-to/gpus#installing_drivers). 

    ```bash
    kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/master/nvidia-driver-installer/cos/daemonset-preloaded.yaml
    ```


## Setup GCS Bucket
### Create GCS bucket in the region
```bash
export BUCKET_NAME=<bucket-name>
gcloud storage buckets create gs://$BUCKET_NAME \
    --location=us-central1 \
    --uniform-bucket-level-access
```

### Set up access to Cloud Storage buckets via GKE Workload Identity

In order to let the CSI driver authenticate with GCP APIs, you will need to do the following steps to make your Cloud Storage buckets accessible by your GKE cluster. See [GKE Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity) for more information.

1. Create a GCP Service Account

    ```bash
    # GCP service account name.
    GCP_SA_NAME=<gcp-service-account-name>
    # Create a GCP service account in the Cloud Storage bucket project.
    gcloud iam service-accounts create ${GCP_SA_NAME} --project=${PROJECT_ID}
    ```

2. Grant the Cloud Storage permissions to the GCP Service Account.
    
    ```bash
    # Run the following command to apply permissions to a specific bucket.
    gcloud storage buckets add-iam-policy-binding gs://${BUCKET_NAME} \
        --member "serviceAccount:${GCP_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role "roles/storage.insightsCollectorService"
    gcloud storage buckets add-iam-policy-binding gs://$BUCKET_NAME \
        --member "serviceAccount:${GCP_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role "roles/storage.objectAdmin"
    ```

3. Create a Kubernetes Service Account.
    
    ```bash
    # Kubernetes namespace where your workload runs.
    K8S_NAMESPACE=<k8s-namespace>
    # Kubernetes service account name.
    export K8S_SA_NAME=<k8s-sa-name>
    # Create a Kubernetes namespace and a service account.
    kubectl create namespace ${K8S_NAMESPACE}
    kubectl create serviceaccount ${K8S_SA_NAME} --namespace ${K8S_NAMESPACE}
    ```

    > Note: The Kubernetes Service Account needs to be in the same namespace where your workload runs.

4. Bind the the Kubernetes Service Account with the GCP Service Account.
    
    ```bash
    gcloud iam service-accounts add-iam-policy-binding ${GCP_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
        --role roles/iam.workloadIdentityUser \
        --member "serviceAccount:${PROJECT_ID}.svc.id.goog[${K8S_NAMESPACE}/${K8S_SA_NAME}]"

    kubectl annotate serviceaccount ${K8S_SA_NAME} \
        --namespace ${K8S_NAMESPACE} \
        iam.gke.io/gcp-service-account=${GCP_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com
    ```


## Test a pod with GCS access

Create a pod with Tensorflow GPU container and access to the bucket created
```bash
envsubst < src/gke-config/standard-tensorflow-bash.yaml | kubectl -n $K8S_NAMESPACE apply -f -
```

Create a dummy test file in the bucket
```bash
touch dummy-file
gsutil cp dummy-file gs://${BUCKET_NAME}

Access the terminal from the tensorflow container
```bash
kubectl -n $K8S_NAMESPACE exec --stdin --tty test-tensorflow-pod --container tensorflow -- /bin/bash
```

Check the bucket contents
```bash
ls /data
```
You should see the `dummy-file` you copied before

Check Tensorflow GPU access
```bash
python -c "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))"
```

You will see some info logs, and at the end it will show that there is one GPU attached to the pod:
`PhysicalDevice(name='/physical_device:GPU:0', device_type='GPU')`

Exit container
```bash
exit
```

Delete test resources
```bash
kubectl -n $K8S_NAMESPACE delete -f src/gke-config/standard-tensorflow-bash.yaml
```


## Train and predict using the MNIST dataset and GPU
### Copy the example code to the bucket
```bash
gsutil -m cp -R src/tensorflow-mnist-example gs://${BUCKET_NAME}/
```
The code will be available for the pod in /data



### Train and evaulate the model on MNIST data
Train a classification model using Keras and the MNIST dataset using GPU
```bash
envsubst < src/gke-config/standard-tf-mnist-train.yaml | kubectl -n $K8S_NAMESPACE apply -f -
```

Wait until the job is in 'Running' state:
```bash
watch kubectl get pods -n $K8S_NAMESPACE
```

```
NAME                       READY   STATUS    RESTARTS   AGE
mnist-training-job-5lkb5   2/2     Running   0          108s
```

Exit the watch command with `CTRL + C` and check the logs from the Tensorflow container.

```bash
kubectl logs -f jobs/mnist-training-job -c tensorflow -n $K8S_NAMESPACE
```

You will see how:
* The required Python packages are installed
* The MNIST training dataset is downloaded
* The model is trained using a GPU
* The trained model is saved
* The model is evaluated

```
...
Epoch 12/12
927/938 [============================>.] - ETA: 0s - loss: 0.0188 - accuracy: 0.9954 
Learning rate for epoch 12 is 9.999999747378752e-06
938/938 [==============================] - 5s 6ms/step - loss: 0.0187 - accuracy: 0.9954 - lr: 1.0000e-05
157/157 [==============================] - 1s 4ms/step - loss: 0.0424 - accuracy: 0.9861
Eval loss: 0.04236088693141937, Eval accuracy: 0.9861000180244446
Training finished. Model saved
******************
Evaluating model with test dataset
Number of devices: 1
157/157 [==============================] - 1s 3ms/step - loss: 0.0424 - accuracy: 0.9861
Eval loss: 0.04236088693141937, Eval Accuracy: 0.9861000180244446
```

Delete training resources

```bash
kubectl -n $K8S_NAMESPACE delete -f src/gke-config/standard-tf-mnist-train.yaml
```


## Predict using the trained model

### Copy the images for prediction to the bucket
```bash
gsutil -m cp -R data/mnist_predict gs://${BUCKET_NAME}/
```

### Predict a folder of images with the trained model
```bash
envsubst < src/gke-config/standard-tf-mnist-batch-predict.yaml | kubectl -n $K8S_NAMESPACE apply -f -
```

Wait until the job is in 'Running' or 'Completed' state:
```bash
watch kubectl get pods -n $K8S_NAMESPACE
```

```
NAME                               READY   STATUS      RESTARTS   AGE
mnist-batch-prediction-job-d8pv7   0/2     Completed   0          42m
```

Exit the watch command with `CTRL + C` and check the logs from the Tensorflow container.

```bash
kubectl logs -f jobs/mnist-batch-prediction-job -c tensorflow -n $K8S_NAMESPACE
```

You will see the prediction for each image, plus the confidence:

```
Found 10 files belonging to 1 classes.
1/1 [==============================] - 2s 2s/step
The image /data/mnist_predict/0.png is the number 0 with a 100.00 percent confidence.
The image /data/mnist_predict/1.png is the number 1 with a 99.99 percent confidence.
The image /data/mnist_predict/2.png is the number 2 with a 100.00 percent confidence.
The image /data/mnist_predict/3.png is the number 3 with a 99.95 percent confidence.
The image /data/mnist_predict/4.png is the number 4 with a 100.00 percent confidence.
The image /data/mnist_predict/5.png is the number 5 with a 100.00 percent confidence.
The image /data/mnist_predict/6.png is the number 6 with a 99.97 percent confidence.
The image /data/mnist_predict/7.png is the number 7 with a 100.00 percent confidence.
The image /data/mnist_predict/8.png is the number 8 with a 100.00 percent confidence.
The image /data/mnist_predict/9.png is the number 9 with a 99.65 percent confidence.
```

## Cleanup

To avoid continuing charges from GCP, you can clean up resources (depending on your case) by

* Deleting the project

* Deleting the GKE cluster and the GCS bucket

```bash
gcloud container clusters delete ${CLUSTER_NAME} 
gsutil rm -r gs://$BUCKET_NAME
```

* Deleting only the resources created in the cluster for this Quick Start and the GCS bucket

```bash
kubectl -n $K8S_NAMESPACE delete -f src/gke-config/standard-tf-mnist-batch-predict.yaml
gsutil rm -r gs://$BUCKET_NAME
```