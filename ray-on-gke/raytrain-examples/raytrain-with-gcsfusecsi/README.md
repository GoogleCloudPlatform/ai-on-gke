**Goal**

In this example we will demonstrate how to setup a ray cluster on GKE and deploy a distributed training job to fine tuning a stable diffusion model following the example from https://docs.ray.io/en/latest/train/examples/pytorch/dreambooth_finetuning.html and artifacts in https://github.com/ray-project/ray/tree/master/doc/source/templates/05_dreambooth_finetuning

We will deploy a jupyter pod and a ray cluster (using kuberay operator). The pods will mount to shared filesystem (GCS Fuse CSI in this specific example) where the model and the datasets live and readily accessible to ray worker pods during training and inference. Ray jobs will be triggered from the jupyter notebook running in the jupyter pod. The example showcases [ray data API](https://docs.ray.io/en/latest/data/api/api.html) usage with a [GKE GCS Fuse CSI](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/cloud-storage-fuse-csi-driver) mounted volumes

![ray-cluster](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/ray-on-gke/raytrain-examples/images/ray-cluster-on-gke.png)

**Setup Steps**

1. Create a GKE cluster with GPU node pool of 4 nodes (1 GPU per GKE node. In this example we used the n1-standard-32 machine type with [T4 GPU](https://cloud.google.com/compute/docs/gpus#nvidia_t4_gpus)). Ensure that Workload Identity and GCS CSI driver is enabled for the cluster. See details [here](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/cloud-storage-fuse-csi-driver#authentication) and [here](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/cloud-storage-fuse-csi-driver#enable)
```
$ gcloud container clusters create $CLUSTER_NAME --location us-central1-c  --workload-pool $PROJECT_ID.svc.id.goog --cluster-version=1.27 --num-nodes=1  --machine-type=e2-standard-32 --addons GcsFuseCsiDriver --enable-ip-alias
$ gcloud container node-pools create gpu-pool --cluster $CLUSTER_NAME --machine-type n1-standard-32 --accelerator type=nvidia-tesla-t4,count=1  --num-nodes=4
```
2. Ensure that the nvidia driver plugins are installed as expected (If not follow the steps [here](https://cloud.google.com/kubernetes-engine/docs/how-to/gpus#installing_drivers))
```
$ kubectl get po -n kube-system | grep nvidia
$ k get po -n kube-system | grep nvidia
nvidia-gpu-device-plugin-medium-cos-c5j8b             1/1     Running   0          8m24s
nvidia-gpu-device-plugin-medium-cos-kpmlr             1/1     Running   0          7m54s
nvidia-gpu-device-plugin-medium-cos-q844w             1/1     Running   0          8m25s
nvidia-gpu-device-plugin-medium-cos-t4q2x             1/1     Running   0          7m17s
```

3. Create a namespace `example` ```kubectl create ns example```
4. Change context to the current namespace
```
kubectl config set-context --current --namespace example
```
5. Install the  kuberay operator and validate operator pod is Running in `example` namespace
```
 helm install kuberay-operator kuberay/kuberay-operator --version 1.0.0-rc.0 --values <path to /raytrain-examples/raytrain-with-gcsfusecsi/kuberay-operator/values.yaml
 $ kubectl get po -n example
pod/kuberay-operator-64b7b88759-5ppfw                   1/1     Running   0   95m
```

6. Deploy the kuberay terraform which sets up the kuberay operator and the ray cluster custom resourcs; spins up a ray head and 3 worker pods. Replace the  `project_id`  in kuberaytf/variables.tf to your own project. Key things to note for this terraform

- The template expects a pre-created bucket of name `test-gcsfuse-1`. If you plan to change it change the bucket name in the raytrain-examples/raytrain-with-gcsfusecsi/kuberaytf/user/variables.tf `gcs_bucket` variable name. Also change the bucket name in raytrain-examples/raytrain-with-gcsfusecsi/kuberaytf/user/modules/kuberay/kuberay-values.yaml csi.volumeAttributes.bucketName in head and worker spec.

- Ray worker and head pods and Jupyter pods mount the bucket with uid=1000, gid=100, so that the necessary directories and artifacts can be downloaded to the shared directory

- The service account bindings of bucket, and Workload Identity bindings between GCP SA and k8s SA are done automatically by the serice_accounts module.

```
 cd kuberaytf/user/
 terraform init
 terraform apply
```
7. Deploy the jupyter Pod and PVC spec (This step expects the service account bindings have been already setup for the GCS Bucket as part of the terraform apply step above)
```
 kubectl apply -f jupyter-spec.yaml
```

8. When all the pods and services are ready this is how it looks like for jupyter and ray pods
```
$ kubectl get all -n example
NAME                                                   READY   STATUS    RESTARTS   AGE
pod/example-cluster-kuberay-head-9x2q6                 2/2     Running   0          3m12s
pod/example-cluster-kuberay-worker-workergroup-95nm2   2/2     Running   0          3m12s
pod/example-cluster-kuberay-worker-workergroup-tfg9n   2/2     Running   0          3m12s
pod/kuberay-operator-64b7b88759-5ppfw                  1/1     Running   0          4m4s
pod/tensorflow-0                                       2/2     Running   0          16s

NAME                                       TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)                                         AGE
service/example-cluster-kuberay-head-svc   ClusterIP      10.8.10.33    <none>        10001/TCP,8265/TCP,8080/TCP,6379/TCP,8000/TCP   3m12s
service/kuberay-operator                   ClusterIP      10.8.14.245   <none>        8080/TCP                                        4m4s
service/tensorflow                         ClusterIP      None          <none>        8888/TCP                                        16s
service/tensorflow-jupyter                 LoadBalancer   10.8.3.9      <pending>     80:31891/TCP                                    16s

NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/kuberay-operator   1/1     1            1           4m4s

NAME                                          DESIRED   CURRENT   READY   AGE
replicaset.apps/kuberay-operator-64b7b88759   1         1         1       4m4s

NAME                          READY   AGE
statefulset.apps/tensorflow   1/1     16s

```
9. Locate the service IP of the jupyter
```
$ kubectl get service tensorflow-jupyter
NAME                 TYPE           CLUSTER-IP    EXTERNAL-IP    PORT(S)        AGE
tensorflow-jupyter   LoadBalancer   10.8.14.182   35.188.214.7   80:31524/TCP   5m33s
```
10. fetch the token for the login
```
$ kubectl exec --tty -i tensorflow-0 -c tensorflow-container -n example -- jupyter server list
Currently running servers:
http://tensorflow-0:8888/?token=<TOKEN> :: /home/jovyan
```
11. Open a new notebook and import the notebook from the URL `https://raw.githubusercontent.com/GoogleCloudPlatform/ai-on-gke/main/ray-on-gke/example_notebooks/raytrain-stablediffusion.ipynb` ([notebook](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/ray-on-gke/example_notebooks/raytrain-stablediffusion.ipynb))

12. Follow the comments and execute the cells in the notebook to run a distributed training job and then inference on the tuned model
13. Port forward the ray service port to examine the ray dashboard for jobs progress details, The dashboard is reachable at localhost:8286 in the local browser
```
kubectl port-forward -n example service/example-cluster-kuberay-head-svc 8265:8265
```
14. During an ongoing traing, the pod resource usage of CPU, Memory, GPU, GPU Memory can be visualized with the GKE Pantheon UI for the workloads
example ![Ray Head resources](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/ray-on-gke/raytrain-examples/images/ray-head-resources.png) and ![Ray Worker resources](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/ray-on-gke/raytrain-examples/images/ray-worker-resources.png)
