# Benchmark on GKE

>[!WARNING]
>This guide and associated code are **deprecated** and no longer maintained.
>
>Please refer to the [GKE AI Labs website](https://gke-ai-labs.dev) for the latest tutorials and quick start solutions.

This directory contains a Terraform template for running [Deep Learning I/O (DLIO) Benchmark](https://github.com/argonne-lcf/dlio_benchmark)
workloads on Google Kubernetes Engine.

## Installation

Preinstall the following on your computer:

* Kubectl
* Terraform
* Gcloud

Note: Terraform keeps state metadata in a local file called `terraform.tfstate`.
If you need to reinstall any resources, make sure to delete this file as well.

The workload identity and `k8s_service_account` should be set up for the `gcs_bucket` and `result_bucket` correctly ahead of time because DLIO jobs need to read from and write to them respectively.

## Run DLIO Job
1. Update the `variables.tf` file with your desired settings to run your machine learning benchmark workload
2. Change the dlio image in `modules/dlio/podspec.tpl` to a desired version. We have tested the job with dlio [commit `ca8d6a3c`](https://github.com/argonne-lcf/dlio_benchmark/tree/ca8d6a3c4159af18397bec95218bf446d6699677).
3. Run `terraform init`
4. Run `terraform apply`
5. After you finish your test, run `terraform destroy` to delete the
   resources

*__Important__*: To isolate results from different runs, `${dlio_benchmark_result}` should be unique to each run.

## Run DLIO Job with Parallelstore
Pre-reqs:
- You'll need to manually setup the VPC peering from the GKE cluster's network to `servicenetworking.googleapis.com`.

1. update `variables.tf` file with your desired settings to run your machine learning benchmark workload, notably set `run_with_gcs_fuse_csi` to `false` and `run_with_parallelstore_csi` to `true`. If you want to use static provisioning, update the "parallelstore variables" and `parallelstore_storageclass` to `""`.
2. Change the dlio image in `modules/dlio/podspec.tpl` to a desired version. We have tested the job with dlio [commit `ca8d6a3c`](https://github.com/argonne-lcf/dlio_benchmark/tree/ca8d6a3c4159af18397bec95218bf446d6699677).
3. run `terraform init`
4. run `terraform apply -target=module.ps_storage`
5. run `terraform apply` after the dataloader job is completed; pvc patch failure is OK for dynamic provisioning.

*__Important__*: To isolate results from different runs, `${dlio_benchmark_result}` should be unique to each run.

## Check Test Result
The test result reports are located in provided GCS bucket `${result_bucket}` in a directory named `${dlio_benchmark_result}`.

## Debug Workload

Describe workload Job
```
kubectl describe job --namespace=benchmark
```
Describe workload Pod
```
kubectl describe pods <pod name> --namespace=benchmark
```
Check dlio container log
```
 kubectl logs <pod name> -c dlio --namespace=benchmark
```

## Example Configurations
Here are example configurations that can be used to run the DLIO benchmark with large,
medium, and small files with Cloud Storage Fuse CSI driver enabled.

### GKE node-pool Configurations

```
enable_gcs_fuse_csi_driver=true
machine_type=n2-highmem-128
ephemeral_storage_local_ssd_config={
   local_ssd_cout=16
}
```

### Workload Configurations
Update the variables defined in the variables.tf file. All other variables should use their default values.

Note: Set dlio_generate_data to "True" to generate dataset. After generate dataset, you need to run `terraform destroy`
and update dlio_generate_data to "False", then `terraform apply` to perform data train.

#### Run DLIO benchmark with large files
```
project_id=<your project id>
gcs_bucket=<your gcs bucket>
// Set dlio_generate_data to "True" to generate dataset, set to "False" to perform data train
dlio_generate_data="True"
dlio_record_length=150000000
dlio_number_of_files=5000
dlio_batch_size=4
gcsfuse_stat_cache_capacity=20000
gcsfuse_stat_cache_ttl=120m0s
gcsfuse_type_cache_ttl=120m0s
```

#### Run DLIO benchmark with medium files
```
project_id=<your project id>
gcs_bucket=<your gcs bucket>
// Set dlio_generate_data to "True" to generate dataset, set to "False" to perform data train
dlio_generate_data="True"
dlio_record_length=3000000
dlio_number_of_files=50000
dlio_batch_size=200
gcsfuse_stat_cache_capacity=200000
gcsfuse_stat_cache_ttl=600m0s
gcsfuse_type_cache_ttl=600m0s
```

#### Run DLIO benchmark with small files
```
project_id=<your project id>
gcs_bucket=<your gcs bucket>
// Set dlio_generate_data to "True" to generate dataset, set to "False" to perform data train
dlio_generate_data="True"
dlio_record_length=500000
dlio_number_of_files=2200000
dlio_batch_size=1200
gcsfuse_stat_cache_capacity=50000000
gcsfuse_stat_cache_ttl=3600m0s
gcsfuse_type_cache_ttl=3600m0s
```
