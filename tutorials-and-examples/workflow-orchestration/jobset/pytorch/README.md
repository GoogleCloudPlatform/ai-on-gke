# Running distributed ML training workloads on GKE using the JobSet API

In this guide you will run a distributed ML training workload on GKE using the [JobSet API](https://github.com/kubernetes-sigs/jobset).
Specifically, you will train a handwritten digit image classifier on the classic MNIST dataset
using PyTorch. The training computation will be distributed across 4 nodes in a GKE cluster.

## Prerequisites
- [Google Cloud](https://cloud.google.com/) account set up.
- [gcloud](https://pypi.org/project/gcloud/) command line tool installed and configured to use your GCP project.
- [kubectl](https://kubernetes.io/docs/tasks/tools/) command line utility is installed.

### 1. Create a GKE cluster with 4 nodes
Run the command: 

```gcloud container clusters create jobset-cluster --zone us-central1-c --num_nodes=4```

You should see output indicating the cluster is being created (this can take ~10 minutes or so).

### 2. Install the JobSet CRD on your cluster
Follow the [JobSet installation guide](https://github.com/kubernetes-sigs/jobset/blob/main/docs/setup/install.md).

### 3. Apply the PyTorch MNIST example JobSet
Run the command: 

```
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/jobset/main/examples/pytorch/cnn-mnist/mnist.yaml

jobset.jobset.x-k8s.io/pytorch created
```

You should see 4 pods created (note the container image is large and may take a few minutes to pull before the container starts running):

```
$ kubectl get pods

NAME                        READY   STATUS              RESTARTS   AGE
pytorch-workers-0-0-ph645   0/1     ContainerCreating   0          6s
pytorch-workers-0-1-mddhj   0/1     ContainerCreating   0          6s
pytorch-workers-0-2-z9ffc   0/1     ContainerCreating   0          6s
pytorch-workers-0-3-f9ps4   0/1     ContainerCreating   0          6s
```

### 4. Observe training logs
You can observe the training logs by examining the pod logs.

```
$ kubectl logs -f pytorch-workers-0-1-drvk6 

+ torchrun --rdzv_id=123 --nnodes=4 --nproc_per_node=1 --master_addr=pytorch-workers-0-0.pytorch --master_port=3389 --node_rank=1 mnist.py --epochs=1 --log-interval=1
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
```