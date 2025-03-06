locals {
  node_count = {
    "llama3.1_7b_nemo_pretraining"     = var.node_count_llama_3_7b
    "llama3.1_70b_nemo_pretraining"    = var.node_count_nemo
    "llama3.1_70b_maxtext_pretraining" = var.node_count_maxtext
    "mixtral8_7b_nemo_pretraining"     = var.node_count_nemo
    "mixtral8_7b_maxtext_pretraining"  = var.node_count_maxtext
    "gke-nccl"                         = var.node_count_gke_nccl
    "gke"                              = var.node_count_gke
  }[local.recipe]
}
