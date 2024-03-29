# Dynamic Workload Scheduler examples

The repository contains examples on how to use DWS in GKE. More information about DWS is 
available [here](https://cloud.google.com/kubernetes-engine/docs/how-to/provisioningrequest).

Files included:

* `kueue-manifests.yaml` - [Kueue](https://kueue.sigs.k8s.io/) configuration files with ProvisioningRequest and DWS support enabled.
* `dws-queue.yaml` - Kueue's Cluster and Local queues with ProvisioningRequest and DWS support enabled.
* `job.yaml` - Sample job that requires GPU and uses DWS-enabled queue. Contains optional annotation ` provreq.kueue.x-k8s.io/maxRunDurationSeconds` which sets `maxRunDurationSeconds` for the created ProvisioningRequest

