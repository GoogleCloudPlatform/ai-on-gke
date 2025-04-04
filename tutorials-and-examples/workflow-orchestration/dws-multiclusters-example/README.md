# Multikueue-dws-integration

This repository provides the files needed to demonstrate how to use MultiKueue with Dynamic Workload Scheduler (DWS) GKE Autopilot.  This setup allows you to run workloads across multiple GKE clusters in different regions, automatically leveraging available GPU resources thanks to DWS.

## Repository Contents

This repository contains the following files:

* `create-clusters.sh`: Script to create the required GKE clusters (one manager and three workers).
* `tf folder`: contains the terraform script to create the required GKE clusters (one manager and three workers). You can use it instead of the bash script.
* `deploy-multikueue.sh`: Script to install and configure Kueue and MultiKueue on the clusters.
* `dws-multi-worker.yaml`: Kueue configuration for the worker clusters, including manager configuration.
* `job-multi-dws-autopilot.yaml`: Example job definition to be submitted to the MultiKueue setup.

## Setup and Usage

### Create Clusters

```
terraform -chdir=tf init
terraform -chdir=tf plan
terraform -chdir=tf apply -var project_id=<YOUR PROJECT ID>
```

### Install Kueue

After creating the GKE clusters and updating your kubeconfig files, install the Kueue components:

```
./deploy-multikueue.sh  
```

### Validate installation

Verify the Kueue installation and the connection between the manager and worker clusters:

```
kubectl get clusterqueues dws-cluster-queue -o jsonpath="{range .status.conditions[?(@.type == \"Active\")]}CQ - Active: {@.status} Reason: {@.reason} Message: {@.message}{'\n'}{end}"
kubectl get admissionchecks sample-dws-multikueue -o jsonpath="{range .status.conditions[?(@.type == \"Active\")]}AC - Active: {@.status} Reason: {@.reason} Message: {@.message}{'\n'}{end}"
kubectl get multikueuecluster multikueue-dws-worker-asia -o jsonpath="{range .status.conditions[?(@.type == \"Active\")]}MC-ASIA - Active: {@.status} Reason: {@.reason} Message: {@.message}{'\n'}{end}"
kubectl get multikueuecluster multikueue-dws-worker-us -o jsonpath="{range .status.conditions[?(@.type == \"Active\")]}MC-US - Active: {@.status} Reason: {@.reason} Message: {@.message}{'\n'}{end}"
kubectl get multikueuecluster multikueue-dws-worker-eu -o jsonpath="{range .status.conditions[?(@.type == \"Active\")]}MC-EU - Active: {@.status} Reason: {@.reason} Message: {@.message}{'\n'}{end}"
```

A successful output should look like this:

```
CQ - Active: True Reason: Ready Message: Can admit new workloads
AC - Active: True Reason: Active Message: The admission check is active
MC-ASIA - Active: True Reason: Active Message: Connected
MC-US - Active: True Reason: Active Message: Connected
MC-EU - Active: True Reason: Active Message: Connected
```

### Launch job

Submit your job to the Kueue controller, which will run it on a worker cluster with available resources:

```
kubectl create -f job-multi-dws-autopilot.yaml
```

### Get the status of the job

To check the job status and see where it's scheduled:

```
kubectl get workloads.kueue.x-k8s.io -o jsonpath='{range .items[*]}{.status.admissionChecks}{"\n"}{end}'
```

In the output message, you can find where the job is scheduled#

### Destroy resources


```
terraform -chdir=tf destroy -var project_id=<YOUR PROJECT ID>
```


