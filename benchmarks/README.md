# AI on GKE Benchmarking

This framework enables you to run automated benchmarks on GKE for AI workloads via Terraform automation.

You can find the current set of supported cluster deployments under `infra/`.


There are currently the following types of benchmarks available:
- **GPU-based benchmark**: running inference servers on GPU based clusters. Can be found in `gpu-benchmark.md`
- **CPU-based benchmark**: simulating AI workload on a large scale. Can be found in `65k-nodes-simulated-ai-workload.md`