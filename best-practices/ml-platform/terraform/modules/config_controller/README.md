# Terraform Module: Config Controller

[Config Controller](https://cloud.google.com/kubernetes-engine/enterprise/config-controller/docs/overview) creates and manages Google Cloud resources with a declarative, Kubernetes model. Config Controller is a hosted version of Config Connector that simplifies installation and maintenance. Config Controller also includes Policy Controller and Config Sync.

Config Controller is available with a Google Kubernetes Engine (GKE) Enterprise edition license.

## Example usage

```
module "config_controller" {
  source = "modules/config_controller"

  full_management      = true
  kubeconfig_directory = local.kubeconfig_directory
  location             = "us-central1"
  name                 = "platform-eng"
  network              = google_compute_network.platform_eng_primary.name
  project_id           = data.google_project.platform_eng.project_id
  subnet               = google_compute_subnetwork.platform_eng_primary.name
}
```
