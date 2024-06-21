# Dynamic Workload Scheduler examples

The repository contains examples on how to use DWS in GKE. More information about DWS is
available [here](https://cloud.google.com/kubernetes-engine/docs/how-to/provisioningrequest).

## Prerequisites

### [Kueue](https://kueue.sigs.k8s.io/)
To install a released version of Kueue in your cluster, run the following command:

```sh
VERSION=v0.7.0
kubectl apply --server-side -f https://github.com/kubernetes-sigs/kueue/releases/download/$VERSION/manifests.yaml
```

For more configuration options visit [Kueue's installation guide.](https://kueue.sigs.k8s.io/docs/installation/)

## Files included

* `dws-queue.yaml` - Kueue's Cluster and Local queues with ProvisioningRequest and DWS support enabled.
* `job.yaml` - Sample job that requires GPU and uses DWS-enabled queue. Contains optional annotation ` provreq.kueue.x-k8s.io/maxRunDurationSeconds` which sets `maxRunDurationSeconds` for the created ProvisioningRequest

