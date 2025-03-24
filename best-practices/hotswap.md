## Use hotswap in your workload
This doc describes how to set up your training job to improve the workload recovery time by utilizing hotswap on Google Kubernetes Engine (GKE).

## Introduction
Hotswap is intended to reduce Mean-Time-To-Recovery(MTTR) by reacting to infrastructure failures and interruptions, and essentially placing the workload onto healthy resources. Workload recovery is gated by the infrastructure repair time, which could take up to 10 minutes depending on the hardware platforms. Hotswap could reduce this time to 1 minute so as to improve the overall training job goodput.

##Hotswap Takes Effect
Hotswap takes effect in 2 main ways:
When the nodes hosting workloads become unhealthy, the job will be rescheduled onto eligible spare nodes upon interruption..
If your workload is configured with PriorityClass, the job that is configured with higher priority will preempt the low priority jobs’ capacities in the same cluster upon interruptions. 


## Example
In this example, we will show how to set up the workload using Jobset together with PriorityClass to achieve hotswap. The training jobs are using multi-host TPU slices and Maxtext framework for illustration.

To begin, let's set up two different Priority Classes to indicate our levels of priority.
```
kind: PriorityClass
metadata:
  name: low-priority-job
value: 1000000
globalDefault: false
description: "This priority class should be used for low priority pods only."
```
```
kind: PriorityClass
metadata:
  name: high-priority-job
value: 2000000
globalDefault: false
description: "This priority class should be used for hero pods only."
```
Now we can create a high priority Jobset workload, making sure to add the priority labels to pod templates, as well as adding the priorityClassName to clearly differentiate the workload's priority. The high priority job is a multi-slice training job running on two 4x4 trillium slices to run a training job with LLama2 7B. 
```
apiVersion: jobset.x-k8s.io/v1alpha2
kind: JobSet
metadata:
  name: high-jax-trillium
  annotations:
    alpha.jobset.sigs.k8s.io/exclusive-topology: cloud.google.com/gke-nodepool
spec:
  failurePolicy:
    maxRestarts: 10
    restartStrategy: BlockingRecreate
  replicatedJobs:
  - name: slice
    replicas: 2
    template:
      spec:
        backoffLimit: 0
        completions: 4
        parallelism: 4
        template:
          spec:
            nodeSelector:
              cloud.google.com/gke-tpu-accelerator: tpu-v6e-slice
              cloud.google.com/gke-tpu-topology: 4x4
            hostNetwork: true
            dnsPolicy: ClusterFirstWithHostNet
            priorityClassName: high-priority-job
            containers:
            - name: jax-program
              image: <IMAGE LOCATION>
              command:
              - python3
              - MaxText/train.py
              - MaxText/configs/base.yml
              - model_name=llama2-7b
              - run_name=<UNIQUE RUN NAME>
              - steps=300 
              - base_output_directory=gs://<OUTPUT BUCKET>
              - dataset_path=gs://max-datasets-rogue
              - max_target_length=4096
              - dataset_type=synthetic
              - enable_checkpointing=False
              resources:
                limits:
                  google.com/tpu: 4
```
Then we can create a low priority Jobset workload, making sure to add the priority labels and the priorityClassName. The low priority job is a single-slice training job running on one 4x4 trillium slice.
```
apiVersion: jobset.x-k8s.io/v1alpha2
kind: JobSet
metadata:
  name: low-jax-trillium
  annotations:
    alpha.jobset.sigs.k8s.io/exclusive-topology: cloud.google.com/gke-nodepool
spec:
  failurePolicy:
    maxRestarts: 10
    restartStrategy: BlockingRecreate
  replicatedJobs:
  - name: slice
    replicas: 1
    template:
      spec:
        backoffLimit: 0
        completions: 4
        parallelism: 4
        template:
          spec:
            nodeSelector:
              cloud.google.com/gke-tpu-accelerator: tpu-v6e-slice
              cloud.google.com/gke-tpu-topology: 4x4
            hostNetwork: true
            dnsPolicy: ClusterFirstWithHostNet
            priorityClassName: low-priority-job
            containers:
            - name: jax-program
              image: <IMAGE LOCATION>
              command:
              - python3
              - MaxText/train.py
              - MaxText/configs/base.yml
              - model_name=llama2-7b
              - run_name=<UNIQUE RUN NAME>
              - steps=300 
              - base_output_directory=gs://<OUTPUT BUCKET>
              - dataset_path=gs://max-datasets-rogue
              - max_target_length=4096
              - dataset_type=synthetic
              - enable_checkpointing=False
              resources:
                limits:
                  google.com/tpu: 4
```
Now that we have clearly differentiated priorities for two different Jobset specifications, we can go ahead and deploy them using
```
kubectl apply -f low_prio_job.yaml
kubectl apply -f high_prio_job.yaml
```
If the high priority job is interrupted by an infrastructure failure, the Jobset will restart the high priority job. The restart will preempt the low priority job so that the high priority job could be rescheduled without waiting for the failed infrastructure recovery. This happens in O(sec), drastically reducing workload idle time. 
If you want to test that your workload setup works, you can simulate workload interruption by draining one of the TPU nodepools that the high priority job is running on: 

```kubectl drain -l cloud.google.com/gke-nodepool=${NODEPOOL_NAME}```

The high priority job is restarted and scheduled onto a healthy node pool. At the same time, the low priority job will be in failed status and belonging leader pod is in pending status. Then go ahead and uncordon the nodes to simulate the recovery of the infrastructure. You will then see the low priority job is rescheduled back to the nodepool that recovered:

```kubectl uncordon -l cloud.google.com/gke-nodepool=${NODEPOOL_NAME}```


