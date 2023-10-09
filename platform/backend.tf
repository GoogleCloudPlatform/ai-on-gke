terraform {
  backend "gcs" {
    bucket  = "juanie-state-bucket"
    prefix  = "terraform/ai-on-gke"
  }
}
