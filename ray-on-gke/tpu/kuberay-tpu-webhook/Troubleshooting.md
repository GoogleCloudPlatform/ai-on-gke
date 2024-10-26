# Ray TPU Webhook Troubleshooting / FAQ Guide
Common issues and their solutions when deploying Ray TPU worker groups with the webhook.
Solutions will be added as new issues are encountered.

## `TPU_WORKER_HOSTNAMES` aren't injected into the Pod environment

### Symptoms
This may be the issue if multi-host Jax initialization fails with error `RuntimeError: Unable to initialize backend 'tpu': UNKNOWN: TPU initialization failed`. Verify that `TPU_WORKER_HOSTNAMES` are missing from the Pod environment with `kubectl describe`. The Pod environment output by `kubectl describe {$POD_NAME}` should look similar to:
```
Containers:
  ray-worker:
  ...
    Environment:
      ...
      TPU_WORKER_HOSTNAMES: list of NumOfHosts DNS hostnames
      TPU_WORKER_ID:        unique Integer between 0 and NumOfHosts representing ID of worker within the Pod slice
      TPU_NAME:             worker group name followed by the replica index (e.g. workergroup-0)
```

### Solution #1
`TPU_WORKER_HOSTNAMES` are only injected for multi-host worker groups. If you're expecting `TPU_WORKER_HOSTNAMES` to be injected, check that the `NumOfHosts` field in your Ray worker group spec is set to a value greater than 1.

### Solution #2
The mutating webhook only intercepts Pods with the label `app.kubernetes.io/name: kuberay`. If environment variables aren't being injected by the webhook, it's possible the Pods are missing this label and it should be added (this label is added automatically to Pods created with Kuberay).

## Internal error occurred: failed calling webhook no endpoints available for service "kuberay-tpu-webhook"

### Solution #1
If attempting to install the webhook on a cluster where a previous version (e.g. v1.0) had been installed, `make uninstall` may fail to delete outdated Deployments, ValidatingWebhookConfigurations, or MutatingWebhookConfigurations, causing this error. To fix this, use `kubectl get` to check for outdated deployments and `kubectl delete` to remove them. Running `make deploy deploy-cert` should now run successfully.

## Internal error occurred: failed calling webhook no endpoints available for service "cert-manager-webhook"

### Solution #1
This error occurs when attempting to run `make deploy-cert` before the cert-manager certificate has become ready. After installing cert-manager in the cluster with `make install-cert-manager` it's usually necessary to wait around 2 minutes before running `make deploy deploy-cert`.

## Admission webhook denied the request: Number of workers in worker group not equal to specified topology

### Solution #1
Check that the `NumOfHosts` field in each Ray TPU worker group is equal to the number of TPU VM hosts expected by a given `gke-tpu-topology` and `gke-tpu-accelerator`. The expected number of hosts is calculated by dividing the total number of TPU chips per slice (e.g. for a 2x2x4 TPU podslice there are 16 chips) by the `google.com/tpu` resource request per worker. Each Ray worker is scheduled on a single node and corresponds to 1 TPU VM host. For more information about choosing a topology, see [TPU configurations](https://cloud.google.com/kubernetes-engine/docs/concepts/tpus#configuration).
### Example:
For a TPU v5e podslice with `gke-tpu-accelerator: tpu-v5-lite-podslice` and `gke-tpu-topology: 2x4`, there may be 1 or 2 TPU VM hosts if the machine type is `ct5lp-hightpu-8t` or `ct5lp-hightpu-4t` respectively. Determine the best configuration for your workload, and set the `google.com/tpu` resource request and limits values to either 8 or 4 based on your chosen machine type. You can then set the `NumOfHosts` field accordingly, and the webhook should admit the RayCluster and inject the desired values into each TPU Pod.

## Webhook calculates number TPU VM hosts incorrectly

### Solution #1
Check the `google.com/tpu` resource request and limits values (these should be equal) in the Ray worker group spec. This value indicates the number of TPU chips requested for each Ray worker (i.e. the number of TPU chips per the VM host). For a `2x2x4` tpu-v4-podslice with 4 TPU chips per VM host, `google.com/tpu` for the Ray worker should be 4. For a `2x4` tpu-v5-podslice with 8 TPU chips per VM host, `google.com/tpu` should be 8. Information about selecting the correct topology, acceleratorType, and corresponding `google.com/tpu` chips per worker can be found in the [TPU versions](https://cloud.google.com/tpu/docs/v5e) docs.
```
workerGroupSpecs:
  template:
    spec:
      containers:
        resources:
          limits:
            google.com/tpu: "{$TPU_CHIPS_PER_WORKER}"
          requests:
            google.com/tpu: "{$TPU_CHIPS_PER_WORKER}"
```
