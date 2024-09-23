# Best Practices

## [AI/ML Platform for enabling AI/ML Ops on GKE Reference Architecture](https://github.com/GoogleCloudPlatform/accelerated-platforms/blob/main/docs/platforms/gke-aiml/README.md)

Construct an Artificial Intelligence/Machine Learning (AI/ML) platform that streamlines AI/ML Operations (AIMLOps), this reference architecture utilizes Google Kubernetes Engine (GKE) as the underlying runtime environment. Additionally, it incorporates a collection of diverse use cases that illustrate practical workflows closely aligned with AI/ML operations.

## [Batch Processing Platform on GKE Reference Architecture](/best-practices/gke-batch-refarch/README.md)

This reference architecture is designed to assist platform administrators, cloud architects, and operations professionals in deploying a batch processing platform on [Google Kubernetes Engine](https://cloud.google.com/kubernetes-engine/docs/concepts/kubernetes-engine-overview) (GKE). Utilizing GKE [Standard](https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-architecture#nodes) as its foundation, this architecture leverages [Kueue](https://kueue.sigs.k8s.io/) to manage resource quotas and borrowing rules between multiple tenant teams sharing the cluster. This enables these teams to run their batch workloads in a fair, cost-efficient, and high-performance manner. Key recommendations for effectively running batch workloads on GKE, as outlined in [Best practices for running batch workloads on GKE](https://cloud.google.com/kubernetes-engine/docs/best-practices/batch-platform-on-gke) are incorporated into this reference architecture.

## [Best Practices for Faster Workload Cold Start](/best-practices/startup-latency.md)

To enhance cold start performance of workloads on Google Kubernetes Engine (GKE), this document provides best practices and examines the elements that influence startup latency.
