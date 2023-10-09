
#######################################################
####    APPLICATIONS
#######################################################
data "google_client_config" "default" {}

provider "google" {
#  project 		= "juanie-newsandbox"  ## REVIEW THIS
 project = var.project_id
 request_timeout 	= "60s"
 region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# config_path = pathexpand("~/.kube/config")

provider "kubernetes" {
  config_path = pathexpand(var.kubeconfig_path)
}

provider "kubectl" {
  config_path = pathexpand(var.kubeconfig_path)
}

provider "helm" {
  kubernetes {
    config_path = pathexpand(var.kubeconfig_path)
  }
}

module "kuberay-operator" {
  source = "../modules/kuberay-operator"
  region       = var.region
  cluster_name = var.cluster_name
}

module "kubernetes-nvidia" {
  source = "../modules/kubernetes-nvidia"
  region           = var.region
  cluster_name     = var.cluster_name
  enable_autopilot = var.enable_autopilot
  enable_tpu       = var.enable_tpu
}

module "kubernetes-namespace" {
  source = "../modules/kubernetes-namespace"
  depends_on      = [module.kubernetes-nvidia, module.kuberay-operator]
  namespace = var.namespace
}

module "k8s_service_accounts" {
  source = "../modules/service_accounts"
  project_id      = var.project_id
  namespace       = var.namespace
  service_account = var.service_account
  depends_on      = [module.kubernetes-namespace]
}

module "kuberay-cluster" {
  source     = "../modules/kuberay-cluster"
  depends_on = [module.kubernetes-namespace]
  namespace  = var.namespace
  enable_tpu = var.enable_tpu
}

module "prometheus" {
  source     = "../modules/prometheus"
  depends_on = [module.kuberay-cluster]
  project_id = var.project_id
  namespace  = var.namespace
}

module "jupyterhub" {
  count = var.create_jupyterhub == true ? 1 : 0
  source           = "../modules/jupyterhub"
  depends_on       = [module.kuberay-cluster, module.prometheus, module.kubernetes-namespace, module.k8s_service_accounts]
  create_namespace = var.create_jupyterhub_namespace
  namespace        = var.jupyterhub_namespace
}



# provider "kubernetes" {
#   host                   = "https://${module.gke_standard.kubernetes_endpoint}"
#   token                  = data.google_client_config.default.access_token
#   cluster_ca_certificate = base64decode(module.gke_standard.ca_certificate)
#   load_config_file = false
# }

# provider "kubectl" {
#   host  = module.gke_standard.kubernetes_endpoint
#   token = data.google_client_config.default.access_token
#   cluster_ca_certificate = base64decode(module.gke_standard.ca_certificate)
#   load_config_file = false
# }

# provider "helm" {
#   kubernetes {
#     ##config_path = pathexpand("~/.kube/config")
#     host  = module.gke_standard.kubernetes_endpoint
#     token = data.google_client_config.default.access_token
#     cluster_ca_certificate = base64decode(
#        module.gke_standard.ca_certificate
#     )
#   }
# }
  
