
if [ -z "$PROJECT_ID" ]; then
    echo "Must provide PROJECT_ID in environment" 1>&2
    exit 2;
fi

if [ -z "$WORKLOAD_IDENTITY" ]; then
    WORKLOAD_IDENTITY=false
fi

kubectl create namespace custom-metrics
kubectl create serviceaccount custom-metrics-stackdriver-adapter -n custom-metrics

# If workload identity is enabled, extra steps are required. We need to:
# - create a service account
# - grant it the monitoring.viewer IAM role
# - bind it to the workload identity user for the cmsa
# - annotate the cmsa service account (done above)
if [ "$WORKLOAD_IDENTITY" == "true" ]; then
    gcloud iam service-accounts create cmsa-sa
    gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:cmsa-sa@$PROJECT_ID.iam.gserviceaccount.com" --role=roles/monitoring.viewer
    gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:cmsa-sa@$PROJECT_ID.iam.gserviceaccount.com" --role=roles/iam.serviceAccountTokenCreator
    gcloud iam service-accounts add-iam-policy-binding --role roles/iam.workloadIdentityUser --member "serviceAccount:$PROJECT_ID.svc.id.goog[custom-metrics/custom-metrics-stackdriver-adapter]" "cmsa-sa@$PROJECT_ID.iam.gserviceaccount.com"
    kubectl annotate serviceaccount custom-metrics-stackdriver-adapter -n custom-metrics "iam.gke.io/gcp-service-account"="cmsa-sa@tpu-vm-gke-testing.iam.gserviceaccount.com"
fi

kubectl apply -f clusterrolebinding_custom-metrics:system:auth-delegator.yaml
kubectl apply -f rolebinding_custom-metrics-auth-reader.yaml
kubectl apply -f clusterrole_custom-metrics-resource-reader.yaml
kubectl apply -f clusterrolebinding_custom-metrics-resource-reader.yaml
kubectl apply -f deployment_custom-metrics-stackdriver-adapter.yaml
kubectl apply -f service_custom-metrics-stackdriver-adapter.yaml
kubectl apply -f apiservice_v1beta1.custom.metrics.k8s.io.yaml
kubectl apply -f apiservice_v1beta2.custom.metrics.k8s.io.yaml
kubectl apply -f apiservice_v1beta1.external.metrics.k8s.io.yaml
kubectl apply -f clusterrolebinding_external-metrics-reader.yaml