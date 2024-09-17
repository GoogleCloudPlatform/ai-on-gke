# Platform Products and Features

This document outlines the products and features that are used in the platform.

![Playground Architecture](/best-practices/ml-platform/docs/images/platform/playground/mlp_playground_architecture_full.svg)

## Cloud Logging

Cloud Logging is a real-time log-management system with storage, search, analysis, and monitoring support. Cloud Logging automatically collects logs from Google Cloud resources. You can also collect logs from your applications, on-premise resources, and resources from other cloud providers. You can also configure alerting policies so that Cloud Monitoring notifies you if certain kinds of events are reported in your logs. For regulatory or security reasons, you can determine where your log data is stored.

For more information see the [Cloud Logging documentation](https://cloud.google.com/logging/docs/overview).

## Cloud Monitoring

Cloud Monitoring services can help you to understand the behavior, health, and performance of your applications and of other Google Cloud services. Cloud Monitoring automatically collects and stores performance information for most Google Cloud services.

For more information see the [Cloud Monitoring documentation](https://cloud.google.com/monitoring/docs/monitoring-overview).

## Identity-Aware Proxy (IAP)

IAP lets you establish a central authorization layer for applications accessed by HTTPS, so you can use an application-level access control model instead of relying on network-level firewalls.

IAP policies scale across your organization. You can define access policies centrally and apply them to all of your applications and resources. When you assign a dedicated team to create and enforce policies, you protect your project from incorrect policy definition or implementation in any application.

For more information see the [Identity-Aware Proxy (IAP) documentation](https://cloud.google.com/iap/docs/concepts-overview).

## Google Cloud Managed Service for Prometheus

Google Cloud Managed Service for Prometheus is Google Cloud's fully managed, multi-cloud, cross-project solution for Prometheus metrics. It lets you globally monitor and alert on your workloads, using Prometheus, without having to manually manage and operate Prometheus at scale.

Managed Service for Prometheus collects metrics from Prometheus exporters and lets you query the data globally using PromQL, meaning that you can keep using any existing Grafana dashboards, PromQL-based alerts, and workflows. It is hybrid- and multi-cloud compatible, can monitor Kubernetes, VMs, and serverless workloads on Cloud Run, retains data for 24 months, and maintains portability by staying compatible with upstream Prometheus. You can also supplement your Prometheus monitoring by querying over 6,500 free metrics in Cloud Monitoring, including free GKE system metrics, using PromQL.

For more information see the [Google Cloud Managed Service for Prometheus documentation](https://cloud.google.com/stackdriver/docs/managed-prometheus).

## Google Kubernetes Engine (GKE)

The Google Kubernetes Engine (GKE) is a managed Kubernetes service that you can use to deploy and operate containerized applications at scale using Google's infrastructure.

For more information see the [Google Kubernetes Engine (GKE) documentation](https://cloud.google.com/kubernetes-engine).

### Cloud Storage FUSE CSI driver

Filesystem in Userspace (FUSE) is an interface used to export a filesystem to the Linux kernel. Cloud Storage FUSE allows you to mount Cloud Storage buckets as a file system so that applications can access the objects in a bucket using common File IO operations (e.g. open, read, write, close) rather than using cloud-specific APIs.

The Cloud Storage FUSE CSI driver lets you use the Kubernetes API to consume pre-existing Cloud Storage buckets as volumes. Your applications can upload and download objects using Cloud Storage FUSE file system semantics. The Cloud Storage FUSE CSI driver provides a fully-managed experience powered by the open source Google Cloud Storage FUSE CSI driver.

For more information see the [Cloud Storage FUSE CSI driver documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/cloud-storage-fuse-csi-driver)

### Cluster autoscaler

GKE's cluster autoscaler automatically resizes the number of nodes in a given node pool, based on the demands of your workloads. When demand is low, the cluster autoscaler scales back down to a minimum size that you designate. This can increase the availability of your workloads when you need it, while controlling costs. You don't need to manually add or remove nodes or over-provision your node pools. Instead, you specify a minimum and maximum size for the node pool, and the rest is automatic.

If resources are deleted or moved when autoscaling your cluster, your workloads might experience transient disruption. For example, if your workload consists of a controller with a single replica, that replica's Pod might be rescheduled onto a different node if its current node is deleted. Before enabling cluster autoscaler, design your workloads to tolerate potential disruption or ensure that critical Pods are not interrupted.

For more information see the [Cluster autoscaler documentation](https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-autoscaler).

### Compute Engine persistent disk CSI Driver

Google Kubernetes Engine (GKE) provides a simple way for you to automatically deploy and manage the Compute Engine persistent disk Container Storage Interface (CSI) Driver in your clusters.

The Compute Engine persistent disk CSI Driver version is tied to the GKE version numbers and is typically the latest driver available at the time that the GKE version is released. The drivers update automatically when the cluster is upgraded to the latest GKE patch.

For more information see the [Compute Engine persistent disk CSI Driver documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/gce-pd-csi-driver)

### Dataplane V2

GKE Dataplane V2 is a dataplane that is optimized for Kubernetes networking. GKE Dataplane V2 provides:

- A consistent user experience for networking.
- Real-time visibility of network activity.
- Simpler architecture that makes it easier to manage and troubleshoot clusters.

GKE Dataplane V2 is implemented using eBPF. As packets arrive at a GKE node, eBPF programs installed in the kernel decide how to route and process the packets. Unlike packet processing with iptables, eBPF programs can use Kubernetes-specific metadata in the packet. This lets GKE Dataplane V2 process network packets in the kernel more efficiently and report annotated actions back to user space for logging.

For more information see the [Dataplane V2 documentation](https://cloud.google.com/kubernetes-engine/docs/concepts/dataplane-v2)

### Dataplane V2 observability

GKE Dataplane V2 observability provides GKE Dataplane V2 metrics and insights into Kubernetes workloads. With GKE Dataplane V2 observability,you can:

- Capture, observe, and alert on network metrics using Google Cloud Managed Service for Prometheus and Cloud Monitoring with Metrics Explorer
- Understand traffic flows for a particular Service in a cluster
- Understand and identify issues with the network health of a Kubernetes workload
- Verify Kubernetes Network Policies

GKE Dataplane V2 observability offers the following troubleshooting tools:

- A Kubernetes cluster Network Topology
- A Kubernetes Network Policy verdict table with live traffic flows and connection information
- Command-line tooling for troubleshooting Kubernetes traffic flows

For more information see the [Dataplane V2 observability documentation](https://cloud.google.com/kubernetes-engine/docs/concepts/about-dpv2-observability)

### Filestore CSI driver

The Filestore CSI driver is the primary way to use Filestore instances with GKE. The CSI driver provides a fully-managed experience powered by the open source Google Cloud Filestore CSI driver.

The CSI driver version is tied to Kubernetes minor version numbers and is typically the latest driver available at the time that the Kubernetes minor version is released. The drivers update automatically when the cluster is upgraded to the latest GKE patch.

For more information see the [Filestore CSI driver](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/filestore-csi-driver)

### Gateway

The GKE Gateway controller is Google's implementation of the Kubernetes Gateway API for Cloud Load Balancing. Similar to the GKE Ingress controller, the Gateway controller watches a Kubernetes API for Gateway API resources and reconciles Cloud Load Balancing resources to implement the networking behavior specified by the Gateway resources.

There are two versions of the GKE Gateway controller:

- Single-cluster: manages single-cluster Gateways for a single GKE cluster.
- Multi-cluster: manages multi-cluster Gateways for one or more GKE clusters.

Both Gateway controllers are Google-hosted controllers that watch the Kubernetes API for GKE clusters. Unlike the GKE Ingress controller, the Gateway controllers are not hosted on GKE control planes or in the user project, enabling them to be more scalable and robust. Both Gateway controllers are Generally Available.

The Gateway controllers themselves are not a networking data plane and they do not process any traffic. They sit out of band from traffic and manage various data planes that process traffic.

For more information see the [Gateway documentation](https://cloud.google.com/kubernetes-engine/docs/concepts/gateway-api)

### Google Virtual NIC (gVNIC)

Google Virtual NIC (gVNIC) is a virtual network interface designed specifically for Compute Engine. gVNIC is an alternative to the virtIO-based ethernet driver.

As the next generation network interface which succeeds VirtIO, gVNIC replaces VirtIO-Net as the only supported network interface in Compute Engine for all new machine types (Generation 3 and onwards). Newer machine series and networking features require gVNIC instead of VirtIO. Consuming gVNIC as the modern I/O interface with Compute Engine VMs offers the following advantages:

- Provides better performance.
- Improves consistency by reducing noisy neighbor problems.
- Introduces new network capabilities beyond what VirtIO is capable of.

gVNIC is supported and recommended on all machine families, machine types, and generations.

gVNIC is required to achieve the following maximum bandwidth rates:

- 50 to 200 Gbps bandwidth with VMs that support per VM Tier_1 networking performance
- 50 to 1,000 Gbps bandwidth with VMs that have attached GPUs

For more information see the [Google Virtual NIC (gVNIC) documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/using-gvnic)

### Image streaming

Image streaming is a method of pulling container images in which GKE streams data from eligible images as requested by your applications. You can use Image streaming to allow your workloads to initialize without waiting for the entire image to download, which leads to significant improvements in initialization times. The shortened pull time provides you with benefits including the following:

- Faster autoscaling
- Reduced latency when pulling large images
- Faster Pod startup

With Image streaming, GKE uses a remote filesystem as the root filesystem for any containers that use eligible container images. GKE streams image data from the remote filesystem as needed by your workloads. Without Image streaming, GKE downloads the entire container image onto each node and uses it as the root filesystem for your workloads.

While streaming the image data, GKE downloads the entire container image onto the local disk in the background and caches it. GKE then serves future data read requests from the cached image.

When you deploy workloads that need to read specific files in the container image, the Image streaming backend serves only those requested files.

To use image streaming, your container images must be stored in Artifact Registry.

For more information see the [Image streaming documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/image-streaming)

### Node auto-provisioning (NAP)

Node auto-provisioning automatically manages and scales a set of node pools on the user's behalf. Without node auto-provisioning, the GKE cluster autoscaler creates nodes only from user-created node pools. With node auto-provisioning, GKE automatically creates and deletes node pools.

For more information see the [Node auto-provisioning (NAP) documentation](https://cloud.google.com/kubernetes-engine/docs/concepts/node-auto-provisioning)

### Observability

Observability is key to understand the health of your applications and maintain application availability and reliability.

When you create a GKE cluster, Cloud Logging, Cloud Monitoring and Google Cloud Managed Service for Prometheus provide observability specifically tailored for Kubernetes.

- Use the built-in dashboards to view default metrics and logs, and to set up recommended alerts.
- Enable additional observability packages to monitor Kubernetes components and objects and use collected data for debugging and troubleshooting.
- Configure data collection for third-party applications running on your clusters.
- Define your own metrics, dashboards, and alerts to meet your needs.

In addition to the integration with Cloud Logging and Cloud Monitoring, GKE also provides other features to help you observe and maintain the health of your applications.

For more information see the [Observability for GKE documentation](https://cloud.google.com/kubernetes-engine/docs/concepts/observability)

### Private cluster

Private clusters use nodes that don't have external IP addresses. This means that clients on the internet cannot connect to the IP addresses of the nodes. Private clusters are ideal for workloads that require controlled access due to data privacy and security regulations.

For more information see the [Private cluster documentation](https://cloud.google.com/kubernetes-engine/docs/concepts/private-cluster-concept)

### Release channels

Use release channels for Google Kubernetes Engine (GKE) to pick versions for your clusters with your chosen balance between feature availability and stability.

GKE automatically upgrades all clusters over time, including those not enrolled in a release channel, to ensure that they receive security updates, fixes to known issues, new features, and run a supported Kubernetes version. You can control the timing of upgrades with maintenance windows and exclusions.

For more information see the [Release channels documentation](https://cloud.google.com/kubernetes-engine/docs/concepts/release-channels)

### Security posture dashboard

The security posture dashboard provides insights about your workload security posture at the runtime phase of the software delivery lifecycle. To gain comprehensive coverage of your applications throughout the lifecycle from source control to maintenance, we recommend that you use the dashboard with other security tooling. For more details about the available tooling and for best practices to safeguard your applications from end to end, see [Protect your software supply chain](https://cloud.google.com/software-supply-chain-security/docs/practices).

For more information see the [Security posture dashboard documentation](https://cloud.google.com/kubernetes-engine/docs/concepts/about-security-posture-dashboard)

### Shielded GKE nodes

Shielded GKE Nodes are built on top of (Compute Engine Shielded VMs)[https://cloud.google.com/compute/shielded-vm/docs/shielded-vm]. Without Shielded GKE Nodes an attacker can exploit a vulnerability in a Pod to exfiltrate bootstrap credentials and impersonate nodes in your cluster, giving the attackers access to cluster secrets. When Shielded GKE Nodes is enabled, the GKE control plane cryptographically verifies that:

- Every node in your cluster is a virtual machine running in Google's data center.
- Every node is part of the Managed Instance Group (MIG) provisioned for the cluster.
- The kubelet is being provisioned a certificate for the node on which it is running.

This limits the ability of an attacker to impersonate a node in your cluster even if they are able to exfiltrate bootstrap credentials of the node.

For more information see the [Shielded GKE nodes documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/shielded-gke-nodes)

#### Integrity monitoring

Integrity monitoring helps you understand and make decisions about the state of your VM instances.

Integrity monitoring relies on the measurements created by Measured Boot, which use platform configuration registers (PCRs) to store information about the components and component load order of both the integrity policy baseline (a known good boot sequence), and the most recent boot sequence.

Integrity monitoring compares the most recent boot measurements to the integrity policy baseline and returns a pair of pass/fail results depending on whether they match or not, one for the early boot sequence and one for the late boot sequence. Early boot is the boot sequence from the start of the UEFI firmware until it passes control to the bootloader. Late boot is the boot sequence from the bootloader until it passes control to the operating system kernel. If either part of the most recent boot sequence doesn't match the baseline, you get an integrity validation failure.

If the failure is expected, for example if you applied a system update on that VM instance, you should update the integrity policy baseline. Updating the integrity policy baseline sets the baseline to the measurements captured from the most recent boot sequence. If it is not expected, you should stop that VM instance and investigate the reason for the failure.

You can view integrity reports in Cloud Monitoring, and set alerts on integrity failures. You can review the details of integrity monitoring results in Cloud Logging. For more information, see Monitoring integrity on Shielded VM instances.

For more information see the [Integrity monitoring documentation](https://cloud.google.com/compute/shielded-vm/docs/shielded-vm?hl=en#integrity-monitoring)

#### Secure boot

Secure Boot helps ensure that the system only runs authentic software by verifying the digital signature of all boot components, and halting the boot process if signature verification fails.

Shielded VM instances run firmware which is signed and verified using Google's Certificate Authority, ensuring that the instance's firmware is unmodified and establishing the root of trust for Secure Boot. The Unified Extensible Firmware Interface (UEFI) 2.3.1 firmware, securely manages the certificates that contain the keys used by the software manufacturers to sign the system firmware, the system boot loader, and any binaries they load. Shielded VM instances use UEFI firmware.

On each boot, the UEFI firmware verifies the digital signature of each boot component against the secure store of approved keys. Any boot component that isn't properly signed, or isn't signed at all, isn't allowed to run.

If this occurs, the VM instance's serial console log will have an entry containing the strings `UEFI: Failed to load image` and `Status: Security Violation`, along with a description of the boot option that failed.

For more information see the [Secure boot documentation](https://cloud.google.com/compute/shielded-vm/docs/shielded-vm?hl=en#secure-boot)

### Workload Identity Federation

Workload Identity Federation for GKE is the recommended way for your workloads running on Google Kubernetes Engine (GKE) to access Google Cloud services in a secure and manageable way. It is available through IAM Workload Identity Federation, which provides identities for workloads that run in environments inside and outside Google Cloud. In GKE, Google Cloud manages the workload identity pool and provider for you and doesn't require an external identity provider.

For more information see the [Workload Identity Federation for GKE documentation](https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity)

### Workload vulnerability scanning

Workload vulnerability scanning is a set of capabilities in the security posture dashboard that automatically scans for known vulnerabilities in your container images and in specific language packages during the runtime phase of the software delivery lifecycle. If GKE detects vulnerabilities, the security posture dashboard displays details about the issues and provides actionable remediation steps to mitigate the vulnerabilities.

For more information see the [Workload vulnerability scanning documentation](https://cloud.google.com/kubernetes-engine/docs/concepts/about-workload-vulnerability-scanning)

## GKE Enterprise

GKE Enterprise is Google's cloud-centric container platform for running modern apps anywhere consistently at scale.

For more information see the [GKE Enterprise documentation](https://cloud.google.com/kubernetes-engine/enterprise/docs/concepts/overview)

### Compliance dashboard

The GKE Compliance dashboard in the Google Cloud console provides actionable insights to strengthen your security posture.

For more information see the [GKE Compliance dashboard documentation](https://cloud.google.com/kubernetes-engine/fleet-management/docs/about-compliance-dashboard)

### Config Sync

Config Sync is a GitOps service built on an open source core that lets cluster operators and platform administrators deploy configurations from a source of truth. The service has the flexibility to support one or many clusters and any number of repositories per cluster or namespace. The clusters can be in a hybrid or multi-cloud environment.

For more information see the [Config Sync documentation](https://cloud.google.com/kubernetes-engine/enterprise/config-sync/docs/overview)

### Connect gateway

The Connect gateway builds on the power of fleets to let users connect to and run commands against fleet member clusters in a simple, consistent, and secured way, whether the clusters are on Google Cloud, other public clouds, or on premises, and makes it easier to automate DevOps processes across all your clusters.

By default the Connect gateway uses your Google ID to authenticate to clusters, with support for third party identity providers using workforce identity federation, and with group-based authentication support via GKE Identity Service.

For more information see the [Connect gateway documentation](https://cloud.google.com/kubernetes-engine/enterprise/multicluster-management/gateway)

### Fleet Management

Fleet management offers a set of capabilities that helps you and your organization manage clusters, infrastructure, and workloads, on Google Cloud and across public cloud and on-premises environments. These capabilities are all built around the idea of the `fleet`: a logical grouping of Kubernetes clusters and other resources that can be managed together. Fleets are managed by the Fleet service, also known as the Hub service.

For more information see the [Fleet management documentation](https://cloud.google.com/kubernetes-engine/fleet-management/docs)

### Policy Controller

Policy Controller enables the application and enforcement of programmable policies for your Kubernetes clusters. These policies act as guardrails and can help with best practices, security, and compliance management of your clusters and fleet. Based on the open source Open Policy Agent Gatekeeper project, Policy Controller is fully integrated with Google Cloud, includes a built-in dashboard, for observability, and comes with a full library of pre-built policies for common security and compliance controls.

For more information see the [Policy Controller documentation](https://cloud.google.com/kubernetes-engine/enterprise/policy-controller/docs/overview
