if [ -z "$PROJECT_ID" ]; then
    echo "Must provide PROJECT_ID in environment" 1>&2
    exit 2;
fi

if [ -z "$RELEASE_NAME" ]; then
    echo "Must provide RELEASE_NAME in environment" 1>&2
    exit 2;
fi

# Adapted from https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.10.0/examples/frontend.yaml
PROMETHEUS_FRONTEND_MANIFEST="$(cat deployment-frontend.json)"
PROMETHEUS_SERVICE_MANIFEST="$(cat service-prometheus.json)"

PROMETHEUS_FRONTEND_MANIFEST="$(echo "$PROMETHEUS_FRONTEND_MANIFEST" \
  | jq \
      --arg PROJECT_ID_ARG "--query.project-id=$PROJECT_ID" \
      '.spec.template.spec.containers[0].args += [$PROJECT_ID_ARG]' \
    )"

echo $PROMETHEUS_FRONTEND_MANIFEST | kubectl apply -f -
echo $PROMETHEUS_SERVICE_MANIFEST | kubectl apply -f -

# TODO: remove when helm uninstall correctly removes this resource on uninstall
kubectl delete apiservice v1beta1.metrics.k8s.io

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install "$RELEASE_NAME" prometheus-community/prometheus-adapter -f values.yaml