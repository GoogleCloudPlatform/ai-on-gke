# Running distributed ML training workloads on GKE using Indexed Jobs

In this guide you will run a distributed ML training workload on GKE using an [Indexed Job](https://kubernetes.io/blog/2021/04/19/introducing-indexed-jobs/).

Specifically, you will train a handwritten digit image classifier on the classic MNIST dataset
using PyTorch. The training computation will be distributed across 4 GPU nodes in a GKE cluster.

## Prerequisites
- [Google Cloud](https://cloud.google.com/) account set up.
- [gcloud](https://pypi.org/project/gcloud/) command line tool installed and configured to use your GCP project.
- [kubectl](https://kubernetes.io/docs/tasks/tools/) command line utility is installed.
- [docker](https://docs.docker.com/engine/install/) is installed.

### 1. Create a standard GKE cluster
Run the command: 

```bash
gcloud container clusters create demo --zone us-central1-c
```

You should see output indicating the cluster is being created (this can take ~10 minutes or so).

### 2. Create a GPU node pool.
You can choose any supported GPU type you wish, using a supported machine type. See the [docs](https://cloud.google.com/kubernetes-engine/docs/how-to/gpus) for more details. In this example, we are using NVIDIA Tesla T4s with the N1 machine family.

```bash
gcloud container node-pools create gpu-pool \
  --accelerator type=nvidia-tesla-t4,count=1,gpu-driver-version=LATEST \
  --machine-type n1-standard-4 \
  --zone us-central1-c --cluster demo \
  --node-locations us-central1-c \
  --num-nodes 4
```

Creating this GPU node pool will take a few minutes.

### 3. Build and push the Docker image to GCR
Make a local copy of the [mnist.py](mnist.py) file which defines a traditional convolutional neural network, as the training logic which trains the model on the classic [MNIST](https://en.wikipedia.org/wiki/MNIST_database) dataset.

Next, make a local copy of the [Dockerfile](Dockerfile) and run the following commands to build the container image and push it to your GCR repository:

```bash
export PROJECT_ID=<your GCP project ID>
docker build -t pytorch-mnist-gpu -f Dockerfile .
docker tag pytorch-mnist-gpu gcr.io/$PROJECT_ID/pytorch-mnist-gpu:latest
docker push gcr.io/$PROJECT_ID/pytorch-mnist-gpu:latest
``` 


### 4. Define an Indexed Job and Headless Service

In the yaml below, we configure an Indexed Job to run 4 pods, 1 for each GPU node, and use [torchrun](https://pytorch.org/docs/stable/elastic/run.html) to kick off a distributed training job for the CNN model on the MNIST dataset. This training job will utilize 1 T4 GPU chip on each node in the node pool.

We also define a [headless service](https://kubernetes.io/docs/concepts/services-networking/service/#headless-services) which selects the
pods owned by this Indexed Job. This will trigger the creation of the DNS records needed for the pods to communicate with eachother
over the network via hostnames.

Copy the yaml below into a local file `mnist.yaml` and be sure to replace `<PROJECT_ID>` with your GCP project ID in the container image.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: headless-svc
spec:
  clusterIP: None 
  selector:
    job-name: pytorchworker
---
apiVersion: batch/v1
kind: Job
metadata:
  name: pytorchworker
spec:
  backoffLimit: 0
  completions: 4
  parallelism: 4
  completionMode: Indexed
  template:
    spec:
      subdomain: headless-svc
      restartPolicy: Never
      nodeSelector:
        cloud.google.com/gke-accelerator: nvidia-tesla-t4
      tolerations:
      - operator: "Exists"
        key: nvidia.com/gpu
      containers:
      - name: pytorch
        image: gcr.io/<PROJECT_ID>/pytorch-mnist-gpu:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 3389
        env:
        - name: MASTER_ADDR
          value: pytorchworker-0.headless-svc
        - name: MASTER_PORT
          value: "3389"
        - name: PYTHONBUFFERED
          value: "0"
        - name: LOGLEVEL
          value: "INFO"
        - name: RANK
          valueFrom:
            fieldRef:
              fieldPath: metadata.annotations['batch.kubernetes.io/job-completion-index']
        command:
        - bash
        - -xc
        - |
          printenv
          torchrun --rdzv_id=123 --nnodes=4 --nproc_per_node=1 --master_addr=$MASTER_ADDR --master_port=$MASTER_PORT --node_rank=$RANK mnist.py --epochs=1 --log-interval=1 
```


### 5. Run the training job

Run the following command to create the Kubernetes resources we defined above and run the training job:

```bash
kubectl apply -f mnist.yaml
```

You should see 4 pods created (note the container image is large and may take a few minutes to pull before the container starts running):

```
$ kubectl get pods
NAME                    READY   STATUS              RESTARTS   AGE
pytorchworker-0-bbsmk   0/1     ContainerCreating   0          15s
pytorchworker-1-92tbl   0/1     ContainerCreating   0          15s
pytorchworker-2-nbrgf   0/1     ContainerCreating   0          15s
pytorchworker-3-rsrdf   0/1     ContainerCreating   0          15s
```

### 4. Observe training logs

Once the pods transition from the `ContainerCreating` status to the `Running` status, you can observe the training logs by examining the pod logs.

```bash
$ kubectl logs -f pytorchworker-1

+ torchrun --rdzv_id=123 --nnodes=4 --nproc_per_node=1 --master_addr=pytorchworker-0.headless-svc --master_port=3389 --node_rank=1 mnist.py --epochs=1 --log-interval=1
Downloading http://yann.lecun.com/exdb/mnist/train-images-idx3-ubyte.gz
Downloading http://yann.lecun.com/exdb/mnist/train-images-idx3-ubyte.gz to ../data/MNIST/raw/train-images-idx3-ubyte.gz
100%|██████████| 9912422/9912422 [00:00<00:00, 90162259.46it/s]
Extracting ../data/MNIST/raw/train-images-idx3-ubyte.gz to ../data/MNIST/raw

Downloading http://yann.lecun.com/exdb/mnist/train-labels-idx1-ubyte.gz
Downloading http://yann.lecun.com/exdb/mnist/train-labels-idx1-ubyte.gz to ../data/MNIST/raw/train-labels-idx1-ubyte.gz
100%|██████████| 28881/28881 [00:00<00:00, 33279036.76it/s]
Extracting ../data/MNIST/raw/train-labels-idx1-ubyte.gz to ../data/MNIST/raw

Downloading http://yann.lecun.com/exdb/mnist/t10k-images-idx3-ubyte.gz
Downloading http://yann.lecun.com/exdb/mnist/t10k-images-idx3-ubyte.gz to ../data/MNIST/raw/t10k-images-idx3-ubyte.gz
100%|██████████| 1648877/1648877 [00:00<00:00, 23474415.33it/s]
Extracting ../data/MNIST/raw/t10k-images-idx3-ubyte.gz to ../data/MNIST/raw

Downloading http://yann.lecun.com/exdb/mnist/t10k-labels-idx1-ubyte.gz
Downloading http://yann.lecun.com/exdb/mnist/t10k-labels-idx1-ubyte.gz to ../data/MNIST/raw/t10k-labels-idx1-ubyte.gz
100%|██████████| 4542/4542 [00:00<00:00, 19165521.90it/s]
Extracting ../data/MNIST/raw/t10k-labels-idx1-ubyte.gz to ../data/MNIST/raw

Train Epoch: 1 [0/60000 (0%)]	Loss: 2.297087
Train Epoch: 1 [64/60000 (0%)]	Loss: 2.550339
Train Epoch: 1 [128/60000 (1%)]	Loss: 2.361300
...

Train Epoch: 1 [14912/60000 (99%)]      Loss: 0.051500
Train Epoch: 1 [5616/60000 (100%)]      Loss: 0.209231
235it [00:36,  6.51it/s]

Test set: Average loss: 0.0825, Accuracy: 9720/10000 (97%)

INFO:torch.distributed.elastic.agent.server.api:[default] worker group successfully finished. Waiting 300 seconds for other agents to finish.
INFO:torch.distributed.elastic.agent.server.api:Local worker group finished (SUCCEEDED). Waiting 300 seconds for other agents to finish
INFO:torch.distributed.elastic.agent.server.api:Done waiting for other agents. Elapsed: 0.0015289783477783203 seconds
```