variable "cluster_name" {
  description = "The name of the cluster NIM will be deployed to"
  type        = string
}

variable "cluster_location" {
  description = "The location of the cluster NIM will be deployed to"
  type        = string
}

variable "google_project" {
  description = "The name of the google project that contains the cluster NIM will be deployed to"
  type        = string
}

variable "kubernetes_namespace" {
  description = "The namespace where NIM will be deployed"
  default     = "nim"
  type        = string
}

variable "gpu_limits" {
  description = "Number of GPUs that will be presented to the model"
  default     = 1
  type        = number
}

variable "ngc_api_key" {
  description = "Your NGC API key"
  type        = string
  sensitive   = true
}

variable "chart_version" {
  description = "The version of the chart"
  default     = "1.1.2"
  type        = string
}

variable "image_name" {
  description = "The name of the image to be deployed by NIM. Should be <org>/<model-name>"
  default     = "meta/llama3-8b-instruct"
  type        = string
}

variable "image_tag" {
  description = "The tag of the image to be deployed by NIM"
  default     = "1.0.0"
  type        = string
}
