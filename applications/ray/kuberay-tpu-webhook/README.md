# TPU Kuberay Webhook Setup Guide

This page contains instructions for how to deploy a mutating admission webhook with Kuberay on TPUs.

### Prerequisites

Preinstall on your computer:
- Docker
- Kubectl
- Terraform
- Helm
- Gcloud

### Installing the GKE Platform

1. If needed, git clone https://github.com/GoogleCloudPlatform/ai-on-gke

2. `cd ai-on-gke/infrastructure`

3. Edit `platform.tfvars` with your desired cluster configuration.

4. Change the region or zone to one where TPUs are available (see [this link](https://cloud.google.com/tpu/docs/regions-zones) for details. For v4 TPUs (the default type), the region should be set to `us-central2` or `us-central2-b`.

5. Set the following flag (note that TPUs are currently only supported on GKE standard):
```
enable_tpu = true
```

6. Change the following lines in the `tpu_pools` configuration if requesting a different [TPU accelerator](https://cloud.google.com/tpu/docs/supported-tpu-configurations#using-accelerator-type). When creating a TPU node pool with autoscaling enabled, these lines can be commented out.
```
accelerator_count      = 2
accelerator_type       = "nvidia-tesla-t4"
```

7. Run `terraform init && terraform apply -var-file platform.tfvars`

8. Run `gcloud container clusters get-credentials %gke_cluster_name% --location=%location%`

### Installing the Webhook

1. `make install-cert-manager` - it may take up to two minutes for the certificate to become ready

2. If deploying webhook across multiple namespaces: `make install-reflector`

6. `make deploy`

7. `make deploy-cert`

### Injecting TPU Environment Variables

After deploying the webhook, follow the steps in ray/TPU_GUIDE to setup Ray on GKE with TPUs. The webhook will intercept Ray clusters and pods created by Kuberay and inject environment variables into pods requesting TPU multi-host resources. Once the Kuberay cluster is deployed, `kubectl describe` the worker pods to verify the `TPU_WORKER_ID`, `TPU_WORKER_HOSTNAMES`, and `TPU_NAME` environment variables have been properly set.

### Limitations

The webhook stores unique `TPU_WORKER_HOSTNAMES` and `TPU_WORKER_ID`s for each slice in memory, and will fail to initialize the environment variables correctly if the webhook pod dies or restarts before intercepting all pods.