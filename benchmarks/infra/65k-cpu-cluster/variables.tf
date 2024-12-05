variable "project_name" {
  type        = string
  description = "Name of the project"
}

variable "cluster_name" {
  type        = string
  description = "Name of the cluster"
}

variable "region" {
  type        = string
  description = "Region to deploy the cluster"
}

variable "vpc_network" {
  type        = string
  description = "Name of the VPC network to use for the cluster"
}
variable "master_ipv4_cidr_block" {
  type        = string
  description = " "
}
variable "cluster_ipv4_cidr_block" {
  type = string
}
variable "services_ipv4_cidr_block" {
  type = string
}
variable "ip_cidr_range" {
  type        = string
  description = " "
}
variable "min_master_version" {
  type        = string
  description = "Minimum master version for the cluster"
}

variable "node_locations" {
  type        = list(string)
  description = "List of zones where nodes will be deployed"
}

variable "initial_node_count" {
  type        = number
  description = "Initial number of nodes in the cluster"
}

variable "datapath_provider" {
  type        = string
  description = "Datapath provider for the cluster (e.g., 'LEGACY_DATAPATH' or 'ADVANCED_DATAPATH')"
}


variable "node_pool_count" {
  type        = number
  description = "Number of additional node pools to create"
}

variable "node_pool_size" {
  type        = number
  description = "Number of nodes in each additional node pool"
}

variable "node_pool_create_timeout" {
  type        = string
  description = "Timeout for creating node pools"
}