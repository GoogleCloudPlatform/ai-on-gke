locals {
  node_count = {
    "llama3.1_7b_nemo_pretraining"   = var.node_count_llama_3_7b
    "llama3.1_70b_nemo_pretraining"  = var.node_count_llama_3_70b
    "gke-nccl"                       = var.node_count_gke_nccl
    "gke"                            = var.node_count_gke
  }[var.recipe]
}
