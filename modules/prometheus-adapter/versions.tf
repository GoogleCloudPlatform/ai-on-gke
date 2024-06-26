terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    kubectl = {
      source = "hashicorp/kubectl"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}