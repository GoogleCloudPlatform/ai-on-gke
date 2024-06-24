if [ -z "$RELEASE_NAME" ]; then
    echo "Must provide RELEASE_NAME in environment" 1>&2
    exit 2;
fi

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install "$RELEASE_NAME" prometheus-community/prometheus-adapter