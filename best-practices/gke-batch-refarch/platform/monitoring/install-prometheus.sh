[[ ! "${PROJECT_ID}" ]] && echo -e "Please export PROJECT_ID variable (export PROJECT_ID=<YOUR POROJECT ID>)\nExiting." && exit 0
echo -e "PROJECT_ID is set to ${PROJECT_ID}"

[[ ! "${REGION}" ]] && echo -e "Please export REGION variable (export REGION=<YOUR REGION, eg: us-central1>)\nExiting." && exit 0
echo -e "REGION is set to ${REGION}"

git clone https://github.com/prometheus-operator/kube-prometheus.git && \
cd kube-prometheus && \
kubectl apply --server-side -f manifests/setup && \
kubectl wait \
    --for condition=Established \
    --all CustomResourceDefinition \
    --namespace=monitoring  && \
kubectl apply -f manifests/ && \
kubectl wait \
    --for condition=Ready \
    --timeout=600s \
    --all Pods \
    --namespace=monitoring && \
kubectl apply -f ../monitoring/kueue-service-monitoring.yaml && \
kubectl apply -f ../monitoring/prometheus-clusterrole.yaml && \
envsubst '$REGION, $PROJECT_ID' < ../monitoring/deploy-dashboard.yaml | kubectl apply -f -
