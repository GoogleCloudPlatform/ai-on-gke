# TPU Provisioner Admission Controller

This is a custom k8s admission controller that can be paired with the TPU provisioner
to dynamically inject node selectors into a Job's pod template based on environment
variables. The TPU provisioner will then provision slices based on the values of
these node selectors.

**NOTE**: This is not a generalized solution that works out of the box for any user - the values
injected by the admission controller are just examples that the user is responsible
for changing to fit their use case.

## Project Structure

```
|- admission_controller.py (mutating webhook)
|- certificates (add TLS certificates here)
|- manifests (deployment manifest for admission controller)
|- test (unit tests)
| - tests
|   |-- admission_controller_test.py (unit tests)
|   |-- manual_e2e/ (JobSet manifests for manual e2e tests)
|       | ...
```

### Prepare container image

1. Build container image: `docker build admission-controller -f Dockerfile .`
2. Tag container image: `docker tag admission-controller gcr.io/${PROJECT}/admission-controller:v0.1.0`
2. Push container image: `docker push gcr.io/${PROJECT}/admission-controller:v0.1.0`

Update the Deployment in `manifests/manifest.yaml` with this container image.

### Local Development

Create a minikube (or kind) cluster.

```bash
minikube create cluster
# OR: kind create cluster
```

Install dependencies.

```bash
kubectl apply --server-side -f https://github.com/kubernetes-sigs/jobset/releases/download/v0.5.1/manifests.yaml
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.yaml
```

Wait for dependencies to become ready. NOTE: You might need to edit/remove Deployment resource requests based on your machine size.

```bash
kubectl rollout status --timeout=30s deployment -n jobset-system jobset-controller-manager
kubectl rollout status --timeout=30s deployment -n cert-manager cert-manager cert-manager-cainjector cert-manager-webhook
```

Deploy the controller locally.

```bash
kubectl create namespace tpu-provisioner-system
skaffold dev
```

### Run Unit tests

This project uses [pytest](https://docs.pytest.org) for unit testing.

To run unit tests, run the command `pytest` from the `admission_controller/` directory.

### Run E2E tests

Run the steps above in the Local Development section. Make sure that the `skaffold dev` step is running.

Run the e2e test script.

```bash
./test/e2e/test.sh
```
