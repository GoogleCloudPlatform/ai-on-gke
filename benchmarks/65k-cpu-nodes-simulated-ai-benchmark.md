# 65k GKE CPU Benchmarks - Simulated AI Benchmark

This repository contains the code and configuration files for benchmarking Google Kubernetes Engine (GKE) at a massive scale (65,000 nodes) with simulated AI workloads via Terraform automation and ClusterLoader2 performance testing tool.

You can find the current set of supported cluster deployments under `infra/65k-cpu-cluster` and the ClusterLoader2 benchmark under `benchmark/tools/CL2-benchmark`.

## Introduction

This benchmark simulates mixed AI workloads, specifically AI training and AI inference, on a 65,000-node GKE cluster. It focuses on evaluating the performance and scalability of the Kubernetes control plane under demanding conditions, specifically with a high number of nodes and dynamic workload changes.

To achieve this efficiently and cost-effectively, the benchmark uses **CPU-only** machines and simulates the behavior of AI workloads with simple containers. This approach allows us to stress-test the Kubernetes control plane without the overhead and complexity of managing actual AI workloads and specialized hardware like GPUs or TPUs.

The benchmark is designed to mimic real-life scenarios encountered in the LLM development and deployment lifecycle, including:

* **Single Workload:** Creating a large training workload allocating the full capacity of the cluster.
* **Mixed Workload:** Running training and inference workloads concurrently.
* **Inference Scale-up:** Scaling up the inference workload to handle increased demand.
* **Training Disruption and Recovery:** Simulating the disruption of training due to inference scale-up and the subsequent recovery of the training workload.


## Setup

### Prerequisites

* **Google Cloud Project:** A Google Cloud project with billing enabled.
* **Terraform:** Terraform installed and configured.
* **gcloud CLI:** gcloud CLI installed and configured with appropriate permissions.
* **Git:** Git installed and configured.


### Creating the Cluster


1. **Clone this repository:**

```bash
git clone https://github.com/GoogleCloudPlatform/ai-on-gke.git
cd 65k-benchmarks/simulated-ai-workload
```
2. **Create and configure `terraform.tfvars`:**

Create a `terraform.tfvars` file. `./sample-tfvars/65k-sample.tfvars` is provided as an example. Copy this file and update the `project_id`, `region`, and `network` variables with your own values.



```bash
cd Terraform
cp ./sample-tfvars/65k-sample.tfvars terraform.tfvars
```


3. **Login to gcloud:**


```bash
gcloud auth application-default login
```



4. **Initialize, plan, and apply Terraform:**


```bash
terraform init

terraform plan

terraform apply
```

5. **Authenticate with the cluster:**

```bash
gcloud container clusters get-credentials <CLUSTER_NAME> --region=<REGION>
```

Replace `<CLUSTER_NAME>` and `<REGION>` with the values used in your `terraform.tfvars` file.

### Running the Benchmark

1. **Clone the perf-tests repository:**


```bash
git clone https://github.com/kubernetes/perf-tests
cd perf-tests

```
2. **Set environment variables:**

```bash
export CL2_DEFAULT_QPS=500
export CL2_ENABLE_VIOLATIONS_FOR_API_CALL_PROMETHEUS_SIMPLE=true
export CL2_INFERENCE_WORKLOAD_INITIAL_SIZE=15000
export CL2_INFERENCE_WORKLOAD_SCALED_UP_SIZE=65000
export CL2_SCHEDULER_NAME=default-scheduler
export CL2_TRAINING_WORKLOAD_MIXED_WORKLOAD_SIZE=50000
export CL2_TRAINING_WORKLOAD_SINGLE_WORKLOAD_SIZE=65000
```
3. **Run the ClusterLoader2 test:**

```bash
./run-e2e-with-prometheus-fw-rule.sh cluster-loader2 \
  --nodes=65000 \
  --report-dir=./output/ \
  --testconfig=../ai-on-gke/65k-benchmarks/simulated-ai-workload/CL2/config.yaml \
  --provider=gke \
  --enable-prometheus-server=true \
  --kubeconfig=${HOME}/.kube/config \
  --v=2
```

The flag `--enable-prometheus-server=true` deploys prometheus server using prometheus-operator.

Make sure that `--testconfig` flag points to the correct path of the benchmark.

## Results

The benchmark results are stored in the `./output/` directory of the `perf-tests` repository. You can use these results to analyze the performance and scalability of your GKE cluster.

The results include metrics such as:

- Pod state transition durations
- Pod startup latency
- Scheduling throughput
- Cluster creation/deletion time (measured from the Terraform logs)
- API server latency


## Cleanup

To avoid incurring unnecessary costs, it's important to clean up the resources created by this benchmark when you're finished.


You can delete the cluster using Terraform:

```bash
cd 65k-benchmarks/simulated-ai-workload/Terraform/
terraform destroy
```