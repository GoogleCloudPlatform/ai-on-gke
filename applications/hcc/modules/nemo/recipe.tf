locals {
  nccl_config = {
    "llama3.1_7b_nemo_pretraining" = "llama3-7b-fp8.yaml"
    "llama3.1_70b_nemo_pretraining"  = "llama3-70b-fp8.yaml"
    "gke-nccl"  = ""
  }[var.recipe]

  workload_image = {
    "A3 Mega"  = "us-central1-docker.pkg.dev/deeplearning-images/reproducibility/pytorch-gpu-nemo@sha256:7a84264e71f82f225be639dd20fcf9104c80936c0f4f38f94b88dfb60303c70e"
    "A3 Ultra" = "us-central1-docker.pkg.dev/deeplearning-images/reproducibility/pytorch-gpu-nemo-nccl:nemo24.07-gib1.0.3-A3U"
  }[var.gpu_type]
}
