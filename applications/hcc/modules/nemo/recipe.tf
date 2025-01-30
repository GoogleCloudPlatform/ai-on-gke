locals {
  nccl_config = {
    "llama3.1_7b_nemo_pretraining" = "llama3-7b-fp8.yaml"
    "llama3.1_70b_nemo_pretraining"  = "llama3-70b-fp8.yaml"
    "gke-nccl"  = ""
  }[var.recipe]
}
