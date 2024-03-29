# Example terraform variables for Ray clusters

This folder contains example terraform variable files to use with the [Ray on GKE terraform templates](/applications/ray/).

To try one of the examples, edit the tfvars file and configure the mandatory variables. Then run the following commands:
```
# from root of ai-on-gke
cd applications/ray
terraform init
terraform apply --var-file=tfvars_examples/<example-file>
```

See [Getting Started](/ray-on-gke/README.md#getting-started) for more details on using the examples in this repo.