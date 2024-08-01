# Reference implementation for regional accelerator GKE clusters

```
vi shared_config/cluster.auto.tfvars
```

```
environment_name       = "env"
environment_project_id = "PROJECT_ID"
region                 = "us-central1"
```

## Apply

```
cd initialize && \
terraform init && \
terraform apply && \
cd ..
```

```
cd networking && \
terraform init && \
terraform apply && \
cd ..
```

```
cd container_cluster && \
terraform init && \
terraform apply && \
cd ..
```

```
cd workloads && \
terraform init && \
terraform apply && \
cd ..
```

## Destroy

```
cd container_cluster && \
terraform destroy
cd ..
```

```
cd networking && \
terraform destroy
cd ..
```

```
cd initialize && \
terraform destroy
cd ..
```
