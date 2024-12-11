variable "region" {
  type    = string
  default = "us-central1"
}

variable "fe_bucket_name" {
  type    = string
  default = "lexitrail-ui"
}

variable "container_name" {
  type    = string
  default = "lexitrail-ui"
}

variable "repository_id" {
  type = string
  default = "lexitrail-repo"
}

variable "sql_namespace" {
  description = "Kubernetes namespace to deploy the resources"
  type        = string
  default     = "mysql"
}

variable "wordsets_csv_path" {
  description = "Path to the CSV file containing wordsets data"
  type        = string
  default     = "csv/wordsets.csv"
}

variable "words_csv_path" {
  description = "Path to the CSV file containing words data"
  type        = string
  default     = "csv/words.csv"
}

variable "db_name" {
  description = "DB name"
  type        = string
  default     = "lexitraildb"
}

variable "backend_namespace" {
  type    = string
  default = "backend"
}

variable "backend_container_name" {
  type    = string
  default = "lexitrail-backend"
}

variable "middel_layer_container_name" {
  type    = string
  default = "middle-layer-app"
}

variable "matchmaker_mmf_container_name" {
  type    = string
  default = "lexitrail-match-making-mmf"
}

variable "matchmaker_director_container_name" {
  type    = string
  default = "lexitrail-match-making-director"
}

variable "matchmaker_frontend_container_name" {
  type    = string
  default = "lexitrail-match-making-frontend"
}

variable "agones_system_namespace" {
  type    = string
  default = "agones-system"
}
