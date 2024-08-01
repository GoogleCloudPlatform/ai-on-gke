locals {
  network_name    = var.network_name != null ? var.network_name : "ml-vpc-${var.environment_name}"
  subnetwork_name = var.subnetwork_name != null ? var.subnetwork_name : var.region
}

variable "dynamic_routing_mode" {
  default     = "GLOBAL"
  description = "VPC dynamic routing mode"
  type        = string
}

variable "network_name" {
  default     = null
  description = "Name of the VPC network"
  type        = string
}

variable "subnet_cidr_range" {
  default     = "10.40.0.0/22"
  description = "CIDR range for the regional subnet"
  type        = string
}

variable "subnetwork_name" {
  default     = null
  description = "Name of the regional subnet"
  type        = string
}
