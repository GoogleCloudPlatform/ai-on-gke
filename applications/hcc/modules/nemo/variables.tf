variable "cluster_id" {
  type = string
}

variable "checkpoint_bucket" {
  type = string
}

variable "recipe" {
  type = string
  validation {
    condition     = contains(["llama3.1_7b_nemo_pretraining", "llama3.1_70b_nemo_pretraining", "gke-nccl"], var.recipe)
    error_message = "Invalid recipe value. Must be one of: llama3.1_7b_nemo_pretraining, llama3.1_70b_nemo_pretraining."
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
