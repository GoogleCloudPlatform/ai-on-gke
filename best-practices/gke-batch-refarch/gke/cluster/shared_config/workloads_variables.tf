locals {
  manifests_directory  = abspath("${path.module}/../manifests")
}

variable "enable_kueue" {
  default = true
}

variable "kueue_version" {
  default = "0.8.0"
}
