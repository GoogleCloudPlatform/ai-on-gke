This module deploys a [prometheus-adapter](https://github.com/kubernetes-sigs/prometheus-adapter) to a cluster. See repo for more details.

## Bash equivalent of this module

Assure the following are set before running
   - PROJECT_ID: GKE Project ID
   - (optional) PROMETHEUS_HELM_VALUES_FILE: Values file to pass when deploying `prometheus-community/prometheus-adapter` chart

```
curl https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.10.0/examples/frontend.yaml | envsubst

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

if [ -z "$PROMETHEUS_HELM_VALUES_FILE" ]
    helm install jetstream prometheus-community/prometheus-adapter
else
    helm install jetstream prometheus-community/prometheus-adapter -f "$PROMETHEUS_HELM_VALUES_FILE"
fi
```
