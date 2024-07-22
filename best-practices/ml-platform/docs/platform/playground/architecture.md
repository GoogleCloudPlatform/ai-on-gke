# Playground Machine learning platform (MLP) on GKE: Architecture

![Playground Architecture](/best-practices/ml-platform/docs/images/platform/playground/mlp_playground_architecture.svg)

## Platform

- [Google Cloud Project](https://console.cloud.google.com/cloud-resource-manager)
  - Environment project
  - Service APIs
- [Cloud Storage](https://console.cloud.google.com/storage/browser)
  - Terraform bucket
- [VPC networks](https://console.cloud.google.com/networking/networks/list)
  - VPC network
    - Subnet
- [Cloud Router](https://console.cloud.google.com/hybrid/routers/list)
  - Cloud NAT gateway
- [Google Kubernetes Engine (GKE)](https://console.cloud.google.com/kubernetes/list/overview)
  - Standard Cluster
    - CPU on-demand node pool
    - CPU system node pool
    - GPU on-demand node pool
    - GPU spot node pool
- Google Kubernetes Engine (GKE) Enterprise ([docs])(https://cloud.google.com/kubernetes-engine/enterprise/docs)
  - Configuration Management
    - Config Sync
    - Policy Controller
  - Connect gateway
  - Fleet
  - Security posture dashboard
    - Threat detection
- Git repository
  - Config Sync

### Each namespace

- [Load Balancer](https://console.cloud.google.com/net-services/loadbalancing/list/loadBalancers)
  - Gateway External Load Balancer
- [Classic SSL Certificate](https://console.cloud.google.com/security/ccm/list/lbCertificates)
  - Gateway SSL Certificate
    - Ray dashboard
- Identity-Aware Proxy (IAP) ([docs])(https://cloud.google.com/iap/docs/concepts-overview)
  - Ray head Backend Service
- [Service Accounts](https://console.cloud.google.com/iam-admin/serviceaccount)
  - Default
  - Ray head
  - Ray worker
