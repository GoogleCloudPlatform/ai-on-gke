variable "cluster_id" {
  type = string
}

variable "checkpoint_bucket" {
  type = string
}

variable "recipe" {
  type = string
  validation {
    condition     = contains(["mixtral8_7b_maxtext_pretraining", "mixtral8_7b_nemo_pretraining", "llama3.1_70b_maxtext_pretraining", "llama3.1_7b_nemo_pretraining", "llama3.1_70b_nemo_pretraining", "gke-nccl", "gke"], var.recipe)
    error_message = "Invalid recipe value. Must be one of: [\"mixtral8_7b_maxtext_pretraining\", \"mixtral8_7b_nemo_pretraining\", \"llama3.1_70b_maxtext_pretraining\", \"llama3.1_7b_nemo_pretraining\", \"llama3.1_70b_nemo_pretraining\", \"gke-nccl\", \"gke\"]."
  }
}

variable "gpu_type" {
  type = string
  validation {
    condition     = contains(["A3 Mega", "A3 Ultra"], var.gpu_type)
    error_message = "Invalid gpu value. Must be one of: A3 Mega, A3 Ultra."
  }
}

variable "node_count" {
  type = number
}

variable "queue" {
  type = string
}

locals {
  node_count_valid = (var.recipe == "gke-nccl" && var.node_count >= 2) || (var.recipe != "gke-nccl" && var.node_count >= 0)
}

resource "null_resource" "node_count_validation" {
  count = 1

  lifecycle {
    precondition {
      condition     = local.node_count_valid
      error_message = "For recipe 'gke-nccl', node_count must be >= 2. For other recipes, node_count must be >= 0."
    }
  }
}