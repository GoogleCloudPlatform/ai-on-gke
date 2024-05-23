# TPU Provisioner

TPU Provisioner is a custom k8s controller which dynamically provisions TPU slices for [JobSets](https://jobset.sigs.k8s.io) based on the workload requirements, and manages the lifecycle of those slices.

## Description

The provisioning process starts with an unschedulable "leader" pod (pod with Job completion index 0) for each Job in the
JobSet. Once the TPU slice is created, the remaining pods for each Job will be created and follow their leader pod
onto the same slice it is running on.

Node Pools are cleaned up when the JobSet whose pods triggered the node pool creation is either **completed, failed, or deleted**.

## Setup

### Create a GKE Cluster with workload identity enabled and no release channel

The TPU Provisioner requires [Workload Identity for GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity) to be enabled, and cannot be on a release channel (auto upgrades
are disabled on node pools created by the TPU provisioner, to minimize disruptions to training workloads).

Refer to the [public docs](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity) and follow
the steps to create a cluster with workload identity enabled.

You should also ensure your cluster is not enrolled in a release channel. The easiest way to do this is in the Google
Cloud Console UI. Search "Kubernetes Engine" in the search bar and select `Kubernetes Engine` from the dropdown,
then click on your cluster to pull up settings that can be configured. Find the `Release Channel` setting, click the
edit button and select `No channel`.

Also note, if you plan to [preload container images via secondary boot disks](https://cloud.google.com/kubernetes-engine/docs/how-to/data-container-image-preloading#create-cluster-secondary-disk) to reduce pod startup latency, you'll
need to enable image streaming, as described in the linked docs.

### Install JobSet

TPU Provisioner dynamically provisions TPU slices for [JobSets](https://jobset.sigs.k8s.io) based on the workload
requirements. 

JobSet is a k8s native API
for running distributed ML training workloads, and is the recommended solution for TPU Multislice training. However, it
is generic and can be used for any arbitrary batch workload as well (GPUs, CPUs, etc). 

Follow the [installation steps](https://jobset.sigs.k8s.io/docs/installation/) to install the latest release of JobSet
in your cluster.

### Permissions

Create TPU Provisioner Service Account, which will be the IAM service account used by the
k8s service account `tpu-provisioner-controller-manageer` to authenticate with Workload Identity.

```sh
gcloud iam service-accounts create tpu-provisioner
export PROVISIONER_SERVICE_ACCOUNT=tpu-provisioner@${PROJECT_ID}.iam.gserviceaccount.com
```

Give the Service Accounts permissions to administer GKE clusters.

```bash
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:${PROVISIONER_SERVICE_ACCOUNT}" --role='roles/container.clusterAdmin'
```

Bind the GCP Service Account to the Kubernetes Service Account that will be attached to the controller Pod.

```sh
gcloud iam service-accounts add-iam-policy-binding ${PROVISIONER_SERVICE_ACCOUNT} \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${PROJECT_ID}.svc.id.goog[tpu-provisioner-system/tpu-provisioner-controller-manager]"
```

### Deployment directory setup

TPU Provisioner deployment configurations are defined on a per cluster level, using config files which live in
a directory structure like follows:

`${REPO_ROOT}/deploy/${PROJECT_ID}/${CLUSTER_NAME}`

You will need to create the `deploy/${PROJECT_ID}/${CLUSTER_NAME}` directory for each you cluster you deploy
the provisioner on.

Next, copy the files from `deploy/example-project/example-cluster` into your new `deploy/${PROJECT_ID}/${CLUSTER_NAME}`
directory and update the templated values in the yaml files to match your own.

### Building and Deploying the Controller

Build and push your image. For example:

```bash
export PROJECT_ID=example-project
export CLUSTER_NAME=ray-cluster
```

```bash
export CONTAINER_IMAGE=us-docker.pkg.dev/${PROJECT_ID}/default/tpu-provisioner:$(git rev-parse --short HEAD)
make docker-build docker-push IMG=${CONTAINER_IMAGE}
```

Set the container image in the manifests.

```bash
cd ./deploy/${PROJECT_ID}/${CLUSTER_NAME}
kustomize edit set image controller=${CONTAINER_IMAGE}
cd -
```

Edit the settings in the `./deploy/${PROJECT_ID}/${CLUSTER_NAME}/` directory to match your project (ConfigMap values and ServiceAccount annotation).

Deploy controller.

```sh
kubectl apply --server-side -k ./deploy/${PROJECT_ID}/${CLUSTER_NAME}
```


## Run an example

After deploying the TPU provisioner on your cluster following the steps above, you can run an example workload to
test that the configurations are set up correctly.

There are 2 things to keep in mind here:

1. You need sufficient quota for whatever TPU machine type you intend to run your workload on.
2. TPU Provisioner operates on [JobSets](https://jobset.sigs.k8s.io) so you'll need to deploy your workload as a JobSet.
See these [JobSet examples](https://jobset.sigs.k8s.io/docs/tasks/) to get started.

This repo includes a simple distributed Jax workload on TPU v4 machines which can be used to verify
your setup is correct.

To apply it, simply run: `k apply -f examples/jobset.yaml` (note: you can tweak JobSet configuration
to define the TPU machine type, number of TPU slices, and their topology).

Next, run `kubectl get pods` to ensure pods have been created - you should see some pending pods.

These pending pods should trigger node pool creation requests for TPU v4 slices of 2x2x2 topology.

Within a few minutes, the node pool creation operations should complete and you should see the pods
transition from `Pending` to `Ready`. In the container logs, you should see the total TPU device count.

## Development

This project is written in Go and uses the [Kubebuilder](https://book.kubebuilder.io/) tool.

For local development and quick manual testing, you can do the following:

Note you’ll need a Kubernetes cluster to run against.

Impersonate the Service Account created above, for example:

```bash
# Assuming you have PROJECT_ID set in your environment...
gcloud config set auth/impersonate_service_account ${PROVISIONER_SERVICE_ACCOUNT}
```

Run the controller (this will run in the foreground, so switch to a new terminal if you want to leave it running), for example:

```bash
GCP_PROJECT_ID=your-project \
GCP_CLUSTER_LOCATION=your-cluster-region \
GCP_ZONE=your-tpu-zone \
GCP_CLUSTER=your-cluster \
GCP_NODE_SERVICE_ACCOUNT=YOUR_PROJECT_NUMBER-compute@developer.gserviceaccount.com \
make run
```

**Note:** When using `make run`, your controller will automatically use the current context in your kubeconfig file (i.e. whatever cluster `kubectl cluster-info` shows).

Test that you can apply a TPU Job.

```bash
kubectl apply -f ./examples/v4-2x2x4/
```
