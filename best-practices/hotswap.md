## Modifing Workload Deployment to Utilize Hotswap
This doc describes how to modify your workload to achieve reduced rescheduling time by utilizing Hotswap on Google Kubernetes Engine (GKE).

# Introduction

Hotswap is intended to reduce MTTR (Median-Time-To-Recovery) by reacting to node failures and interuptions, and essentially swapping them out for healthy, active hardware. It is used fungible over both GPUs and TPUs to help reduce the Workload Rescheduling time, as that is often a bottleneck when dealing with interuptions. Traditionally, without Hotswap, customers have to wait till the unhealthy nodes hosting the workloads recover, which can take > 5 minutes. With Hotswap, we can bring it down to O(secs).

# Hotswap Takes Effect

Hotswap takes effect in 2 main ways:
1) When a node hosting workloads become unhealthy, it looks for a spare, eligible accelerator hardware to replace. This is a simple swap of the hardware hosting the workload with the spare.
2) When a node hosting workloads become unhealthy, if there are no spares, it will evict a *lower priority* workload, from an eligible slice, and transfer the accelerator hardware to this *higher priority* job. Priority in this case is depicted by a priority class, making this a more nuanced scenario, that requires a little setup.

**Note:** Scenario 2  takes effect when multiple workloads are running on the **same cluster**, and they are sharing the same set of accelerator nodepools. 

#### Priority Classes
For Hotswap to work, we need to attach a PriorityClass to the workloads. PriorityClasses help differentiate how to select which workload to preempt versus not. **This is different than job level priority**. Thankfully, Kubernetes makes it super easy to incorporate these classes into your workloads.

### Example
To begin, lets setup two different Priority Classes to indicate our levels of priority. The first class will have a lower priority by indicating a lower value, 1000000, and the higher priority class will have a value of 2000000, having a clear differentiation. 

```apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: low-prior-job
value: 1000000
globalDefault: false
description: "This priority class should be used for low priority pods only."
```
```apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-prior-job
value: 2000000
globalDefault: false
description: "This priority class should be used for hero pods only."
```

Now we can create a high priority Jobset Workload, making sure to add the priority labels to pod templates, as well as adding the priorityClassName to clearly differentiate the workload's priority. This workload will utilize v6e TPUs, with a topology of 4x4, to run a training job on LLama2-7B. **This is an example workload so you would personalize the hardware to fit your needs.** This will be located in high_prio_job.yaml.
```

apiVersion: jobset.x-k8s.io/v1alpha2
kind: JobSet
metadata:
  name: high-jax-v6e
  annotations:
    alpha.jobset.sigs.k8s.io/exclusive-topology: cloud.google.com/gke-nodepool
spec:
  failurePolicy:
    maxRestarts: 10
    restartStrategy: BlockingRecreate
  replicatedJobs:
  - name: slice
    replicas: 
    template:
      spec:
        backoffLimit: 0
        completions: 4
        parallelism: 4
        template:
          metadata:
            labels:
              priority: high
          spec:
            nodeSelector:
              cloud.google.com/gke-tpu-accelerator: tpu-v6e-slice
              cloud.google.com/gke-tpu-topology: 4x4
            #restartPolicy: Never
            hostNetwork: true
            dnsPolicy: ClusterFirstWithHostNet
            priorityClassName: high-prior-job
            containers:
            - name: jax-program
              image: gcr.io/tpu-prod-env-one-vm/rishi_v6e_test
              command:
              - python3
              - MaxText/train.py
              - MaxText/configs/base.yml
              - model_name=llama2-7b
              - run_name=rishibathinav6e
              - steps=300 
              - base_output_directory=gs://tpu-vm-v6e-bucket
              - dataset_path=gs://max-datasets-rogue
              - max_target_length=4096
              - dataset_type=synthetic
              - enable_checkpointing=False
              resources:
                limits:
                  google.com/tpu: 4
```
Then we can create a low priority Jobset Workload, again making sure to add the priority labels and the priorityClassName. Again, it is the same training job as the high priority job, but with a lower PriorityClass. This will be located in low_prio_job.yaml.

```
apiVersion: jobset.x-k8s.io/v1alpha2
kind: JobSet
metadata:
  name: low-jax-v6e
  annotations:
    alpha.jobset.sigs.k8s.io/exclusive-topology: cloud.google.com/gke-nodepool
spec:
  failurePolicy:
    maxRestarts: 10
    restartStrategy: BlockingRecreate
  replicatedJobs:
  - name: slice
    replicas: 
    template:
      spec:
        backoffLimit: 0
        completions: 4
        parallelism: 4
        template:
          metadata:
            labels:
              priority: low
          spec:
            nodeSelector:
              cloud.google.com/gke-tpu-accelerator: tpu-v6e-slice
              cloud.google.com/gke-tpu-topology: 4x4
            #restartPolicy: Never
            hostNetwork: true
            dnsPolicy: ClusterFirstWithHostNet
            priorityClassName: low-prior-job
            containers:
            - name: jax-program
              image: gcr.io/tpu-prod-env-one-vm/rishi_v6e_test
              command:
              - python3
              - MaxText/train.py
              - MaxText/configs/base.yml
              - model_name=llama2-7b
              - run_name=rishibathinav6e
              - steps=300 
              - base_output_directory=gs://tpu-vm-v6e-bucket
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

Now, when a infrastruction interruption takes place that interrupts your high prio job, it will evict the low prio job's pods off their nodes, and give the high prio job those nodes to schedule on. This happens in O(sec), drastically reducing workload idle time. If you want to test that your workload setup works, you can simulate workload disruption by cordoning the nodepool that one of your high prio jobs is running on:
```kubectl cordon -l cloud.google.com/gke-nodepool={$NODEPOOL_NAME}```

You will see the high priority jobs are restarted and scheduled onto a healthy node pool. At the same time, the low priority job is in failed status and belonging leader pod is in pending status. Then go ahead and uncordon the nodes to simulate the recovery of the infrastructure. You will then see the low priority job is rescheduled back to the nodepool that recovered:

```kubectl uncordon -l cloud.google.com/gke-nodepool={$NODEPOOL_NAME}```
