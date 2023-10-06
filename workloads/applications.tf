
#######################################################
####    APPLICATIONS
#######################################################

provider "kubernetes" {
  config_path = pathexpand("~/.kube/config")
}

provider "helm" {
  kubernetes {
    config_path = pathexpand("~/.kube/config")
  }
}

resource "helm_release" "hello" {
  name             = "helloworld"
  repository       = "https://helm.github.io/examples"
  chart            = "hello-world"
  namespace        = "default"
  create_namespace = "false"
  cleanup_on_fail  = "true"
}


