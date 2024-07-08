This module deploys a [prometheus-adapter](https://github.com/kubernetes-sigs/prometheus-adapter) and a [Prometheus frontend](https://github.com/GoogleCloudPlatform/prometheus-engine/blob/main/examples/frontend.yaml) to a cluster. See [prometheus-adapter](https://github.com/kubernetes-sigs/prometheus-adapter) repo for more details.

## Installation via bash and helm

Assure the following environment variables are set:
   - PROJECT_ID: GKE Project ID
   - (optional) PROMETHEUS_HELM_VALUES_FILE: Values file to pass when deploying `prometheus-community/prometheus-adapter` chart

```
curl https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.10.0/examples/frontend.yaml | envsubst | kubectl apply -f -

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

if [ -z "$PROMETHEUS_HELM_VALUES_FILE" ]
    helm install example-release prometheus-community/prometheus-adapter
else
    helm install example-release prometheus-community/prometheus-adapter -f "$PROMETHEUS_HELM_VALUES_FILE"
fi
```
