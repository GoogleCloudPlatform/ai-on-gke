locals {
  nccl_config = {
    "llama3.1_7b_nemo_pretraining"     = "llama3-7b-fp8.yaml"
    "llama3.1_70b_nemo_pretraining"    = "llama3-70b-fp8.yaml"
    "llama3.1_70b_maxtext_pretraining" = "llama3-70b-bf16.yaml"
    "mixtral8_7b_nemo_pretraining"     = "mixtral8-7b-bf16.yaml"
    "mixtral8_7b_maxtext_pretraining"  = "mixtral8-7b-bf16.yaml"
    "gke-nccl"                         = ""
    "gke-ray"                          = ""
  }[var.recipe]

  model_type = {
    "llama3.1_7b_nemo_pretraining"     = "nemo-training"
    "llama3.1_70b_nemo_pretraining"    = "nemo-training"
    "llama3.1_70b_maxtext_pretraining" = "maxtext-training"
    "mixtral8_7b_nemo_pretraining"     = "nemo-training"
    "mixtral8_7b_maxtext_pretraining"  = "maxtext-training"
    "gke-nccl"                         = ""
    "gke-ray"                          = ""
  }[var.recipe]

  values_file = {
    "llama3.1_7b_nemo_pretraining"     = "values.yaml"
    "llama3.1_70b_nemo_pretraining"    = "values.yaml"
    "llama3.1_70b_maxtext_pretraining" = "llama3-70b-bf16-values.yaml"
    "mixtral8_7b_nemo_pretraining"     = "values.yaml"
    "mixtral8_7b_maxtext_pretraining"  = "mixtral8-7b-bf16-values.yaml"
    "gke-nccl"                         = ""
    "gke-ray"                          = ""
  }[var.recipe]

}
