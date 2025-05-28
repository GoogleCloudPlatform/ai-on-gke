# AI on GKE Benchmarking

>[!WARNING]
>This guide and associated code are **deprecated** and no longer maintained.
>
>Please refer to the [GKE AI Labs website](https://gke-ai-labs.dev) for the latest tutorials and quick start solutions.
>
>Please refer to the [Inference Benchmark](https://gke-ai-labs.dev/docs/benchmarking/inference-benchmark/) for the latest inference benchmarking tutorial.
>
>Please refer to the [GKE at 65,000 Nodes: Simulated AI Workload Benchmark](https://gke-ai-labs.dev/docs/benchmarking/cpu-based-benchmark/) for the latest 65k benchmarking tutorial.

This framework enables you to run automated benchmarks on GKE for AI workloads via Terraform automation.

You can find the current set of supported cluster deployments under `infra/`.


There are currently the following types of benchmarks available:
- **Accelerator-based benchmark**: running inference servers on accelerator-based clusters (both GPU and TPU). Can be found in `accelerator-based-ai-benchmark.md`
- **CPU-based benchmark**: simulating AI workload on a large scale on CPU-based clusters. Can be found in `65k-cpu-nodes-simulated-ai-benchmark.md`