# AI on GKE Benchmarking

This framework enables you to run automated benchmarks on GKE for AI workloads via Terraform automation.

You can find the current set of supported cluster deployments under `infra/`.


There are currently the following types of benchmarks available:
- **Accelerator-based benchmark**: running inference servers on accelerator-based clusters (both GPU and TPU). Can be found in `accelerator-based-ai-benchmark.md`
- **CPU-based benchmark**: simulating AI workload on a large scale on CPU-based clusters. Can be found in `65k-cpu-nodes-simulated-ai-benchmark.md`