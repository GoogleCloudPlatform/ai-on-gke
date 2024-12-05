This directory contains the Terraform templates for setting up a GPU
cluster for benchmarking. If you already have a cluster, you can ignore
these steps.

You should run stage-1 first and stage-2 second. You can find more details in the respective stage README's.

The expected workflow for creating a cluster is the following:

### Stage 1: Create a GKE cluster with GPU accelerators

Stage 1 creates a GKE cluster with GPU accelerators. You can find more details in the stage-1/README.md.
At a high level you will run the following:

```
cd infra/accelerator-cluster/stage-1

cp ./sample-tfvars/gpu-sample.tfvars terraform.tfvars

terraform init

terraform plan

terraform apply
```

### Stage 2: Configure the cluster

Stage 2 configures additional worklaods on the GKE cluster with GPU accelerators for running inference workloads.
You can find more details in the stage-2/README.md. At a high level you will run the following:

```
cd infra/stage-2

cp ./sample-tfvars/gpu-sample.tfvars terraform.tfvars

terraform init

terraform plan

terraform apply
```

## Additional Notes

The accelerator type can be changed to use TPU's instead of GPUs as desired.