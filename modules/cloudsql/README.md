# CloudSQL
This module contains a Terraform template for creating a CloudSQL instance.

## Usage

1. Edit `variables.tf` with your GCP settings.
2. Run `terraform init` and `terraform apply`
3. Create an IAM service account & grant a cloudsql client role to it:
```
gcloud projects add-iam-policy-binding {PROJECT_ID} \
  --member=serviceAccount:{SA_ACCOUNT}.iam.gserviceaccount.com \
  --role="roles/cloudsql.client"
```

Note: Ensure that the regional subnet that is used (referenced by `network_name`) has [Private Service Connect](https://cloud.google.com/vpc/docs/private-service-connect) enabled.

See [sample RAG application](https://github.com/GoogleCloudPlatform/ai-on-gke/applications/rag/README.md) for example usage of the created instance.