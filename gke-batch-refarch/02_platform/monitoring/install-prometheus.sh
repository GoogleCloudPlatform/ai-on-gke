[[ ! "${PROJECT_ID}" ]] && echo -e "Please export PROJECT_ID variable (\e[95mexport PROJECT_ID=<YOUR POROJECT ID>\e[0m)\nExiting." && exit 0
echo -e "\e[95mPROJECT_ID is set to ${PROJECT_ID}\e[0m"

[[ ! "${REGION}" ]] && echo -e "Please export REGION variable (\e[95mexport REGION=<YOUR REGION, eg: us-central1>\e[0m)\nExiting." && exit 0
echo -e "\e[95mREGION is set to ${REGION}\e[0m"

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