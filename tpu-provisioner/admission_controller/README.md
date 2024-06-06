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

Deploy the controller locally.

```bash
skaffold dev
```

### Run Unit tests

This project uses [pytest](https://docs.pytest.org) for unit testing.

To run unit tests, run the command `pytest` from the `admission_controller/` directory.

### Run E2E tests

E2E testing is currently done manually via the following steps:

1. [Install JobSet](https://jobset.sigs.k8s.io/docs/installation/)
2. **Deploy admission controller**: Run `kubectl apply -f manifests/` from the `admission_controller/` directory.
3. **Create a test JobSet**: Run `kubectl apply -f test/test-jobset.yaml`
4. **Check Jobs were mutated correctly**: Run `kubectl describe jobs` and view the nodeSelectors in the pod template.
