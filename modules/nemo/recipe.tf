locals {
  nccl_config = {
    "llama3.1_7b_nemo_pretraining"     = "llama3-7b-fp8.yaml"
    "llama3.1_70b_nemo_pretraining"    = "llama3-70b-fp8.yaml"
    "llama3.1_70b_maxtext_pretraining" = "llama3-70b-bf16.yaml"
    "mixtral8_7b_nemo_pretraining"     = "mixtral8-7b-bf16.yaml"
    "mixtral8_7b_maxtext_pretraining"  = "mixtral8-7b-bf16.yaml"
    "gke-nccl"                         = ""
  }[var.recipe]

  model_type = {
    "llama3.1_7b_nemo_pretraining"     = "nemo-training"
    "llama3.1_70b_nemo_pretraining"    = "nemo-training"
    "llama3.1_70b_maxtext_pretraining" = "maxtext-training"
    "mixtral8_7b_nemo_pretraining"     = "nemo-training"
    "mixtral8_7b_maxtext_pretraining"  = "maxtext-training"
    "gke-nccl"                         = ""
  }[var.recipe]

  values_file = {
    "llama3.1_7b_nemo_pretraining"     = "values.yaml"
    "llama3.1_70b_nemo_pretraining"    = "values.yaml"
    "llama3.1_70b_maxtext_pretraining" = "llama3-70b-bf16-values.yaml"
    "mixtral8_7b_nemo_pretraining"     = "values.yaml"
    "mixtral8_7b_maxtext_pretraining"  = "mixtral8-7b-bf16-values.yaml"
    "gke-nccl"                         = ""
  }[var.recipe]

  machine_type_label = var.gpu_type == "A3 Mega" ? "a3mega" : (var.gpu_type == "A3 Ultra" ? "a3ultra" : "unknown")

  framework_label = {
    "llama3.1_7b_nemo_pretraining"     = "nemo"
    "llama3.1_70b_nemo_pretraining"    = "nemo"
    "llama3.1_70b_maxtext_pretraining" = "maxtext"
    "mixtral8_7b_nemo_pretraining"     = "nemo"
    "mixtral8_7b_maxtext_pretraining"  = "maxtext"
    "gke-nccl"                         = "nccltest"
  }[var.recipe]

  model_label = {
    "llama3.1_7b_nemo_pretraining"     = "llama-3.1-7b"
    "llama3.1_70b_nemo_pretraining"    = "llama-3.1-70b"
    "llama3.1_70b_maxtext_pretraining" = "llama-3.1-70b"
    "mixtral8_7b_nemo_pretraining"     = "mixtral-8-7b" 
    "mixtral8_7b_maxtext_pretraining"  = "mixtral-8-7b" 
    "gke-nccl"                         = null
  }[var.recipe]
 
  workload_labels = merge(
    {
      "ai-on-gke-solution"     = "cluster-director-quick-start-solution"
      "ai-on-gke-machine-type" = local.machine_type_label
      "ai-on-gke-framework"    = local.framework_label
    },
    
    local.model_label != null ? { "ai-on-gke-model" = local.model_label } : {}
  )

}
