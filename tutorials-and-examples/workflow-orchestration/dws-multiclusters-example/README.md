# Create Clusters

```
./create-clusters.sh 
```

# Install Kueue

```
./deploy-multikueue.sh  
```

## Validate installation

```
kubectl get clusterqueues dws-cluster-queue -o jsonpath="{range .status.conditions[?(@.type == \"Active\")]}CQ - Active: {@.status} Reason: {@.reason} Message: {@.message}{'\n'}{end}"
kubectl get admissionchecks sample-dws-multikueue -o jsonpath="{range .status.conditions[?(@.type == \"Active\")]}AC - Active: {@.status} Reason: {@.reason} Message: {@.message}{'\n'}{end}"
kubectl get multikueuecluster multikueue-dws-worker-asia -o jsonpath="{range .status.conditions[?(@.type == \"Active\")]}MC-ASIA - Active: {@.status} Reason: {@.reason} Message: {@.message}{'\n'}{end}"
kubectl get multikueuecluster multikueue-dws-worker-us -o jsonpath="{range .status.conditions[?(@.type == \"Active\")]}MC-US - Active: {@.status} Reason: {@.reason} Message: {@.message}{'\n'}{end}"
kubectl get multikueuecluster multikueue-dws-worker-eu -o jsonpath="{range .status.conditions[?(@.type == \"Active\")]}MC-EU - Active: {@.status} Reason: {@.reason} Message: {@.message}{'\n'}{end}"
```

Output : 

```
CQ - Active: True Reason: Ready Message: Can admit new workloads
AC - Active: True Reason: Active Message: The admission check is active
MC-ASIA - Active: True Reason: Active Message: Connected
MC-US - Active: True Reason: Active Message: Connected
MC-EU - Active: True Reason: Active Message: Connected
```

# Launch job



```
kubectl create -f job-multi-dws-autopilot.yaml
```

## Get the status of the job

```
kubectl  get workloads.kueue.x-k8s.io -o jsonpath='{.items[0].status.admissionChecks}'
```

In the output message, you can find where the job is scheduled

