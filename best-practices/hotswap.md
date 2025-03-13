## Modifing Workload Deployment to Utilize Hotswap
This doc describes how to modify your workload to achieve reduced rescheduling time by utilizing Hotswap on Google Kubernetes Engine (GKE).

# Introduction

Hotswap is intended to reduce MTTR (Median-Time-To-Recovery) by reacting to node failures and interuptions, and essentially swapping them out for healthy, active hardware. It is used fungible over both GPUs and TPUs to help reduce the Workload Rescheduling time, as that is often a bottleneck when dealing with interuptions. Traditionally, without Hotswap, customers have to wait till the unhealthy nodes hosting the workloads recover, which can take > 5 minutes. With Hotswap, we can bring it down to O(secs).

# Hotswap Takes Effect

Hotswap takes effect in 2 main ways:
1) When a node hosting workloads become unhealthy, it looks for a spare, idle hardware slice to replace. This is a simple swap of the hardware hosting the workload with the spare.
2) When a node hosting workloads become unhealthy, if there are no spares, it will evict a *lower priority* workload from a slice, and transfer the slice to this *higher priority* job. This is the more nuanced scenario, that requires a little setup.

#### Priority Classes
To connect back to the concept of priority levels on workloads, we will use **PriorityClasses** to provide the priority indicator for the Hotswap algorithm.

```apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: low-prior-job
value: 1000000
globalDefault: false
description: "This priority class should be used for low priority pods only."
