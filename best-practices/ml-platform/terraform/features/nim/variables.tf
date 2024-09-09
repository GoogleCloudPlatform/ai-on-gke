variable "cluster-name" {
  description = "The name of the cluster NIM will be deployed to"
  type        = string
}

variable "cluster-location" {
  description = "The location of the cluster NIM will be deployed to"
  type        = string
}

variable "google-project" {
  description = "The name of the google project that contains the cluster NIM will be deployed to"
  type        = string
}

variable "kubernetes-namespace" {
  description = "The namespace where NIM will be deployed"
  default     = "nim"
  type        = string
}

variable "gpu-limits" {
  description = "Number of GPUs that will be presented to the model"
  default = 1
  type = number
}

variable "ngc-api-key" {
  description = "Your NGC API key"
  type        = string
  sensitive   = true
}

variable "chart-version" {
  description = "The version of the chart"
  default     = "1.1.2"
  type        = string
}

variable "image-name" {
  description = "The name of the image to be deployed by NIM. Should be <org>/<model-name>"
  default     = "meta/llama3-8b-instruct"
  type        = string
}

variable "image-tag" {
  description = "The tag of the image to be deployed by NIM"
  default     = "1.0.0"
  type        = string
}
