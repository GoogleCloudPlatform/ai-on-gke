# Custom Metrics Stackdriver Adapter

Adapted from https://raw.githubusercontent.com/GoogleCloudPlatform/k8s-stackdriver/master/custom-metrics-stackdriver-adapter/deploy/production/adapter_new_resource_model.yaml

## Installation via bash, gcloud, and kubectl

Assure the following environment variables are set:
   - PROJECT_ID: Your GKE project ID
   - WORKLOAD_IDENTITY: Is workload identity federation enabled in the target cluster?

```
if [ -z "$WORKLOAD_IDENTITY" ]; then
    WORKLOAD_IDENTITY=false
fi

kubectl create namespace custom-metrics
kubectl create serviceaccount custom-metrics-stackdriver-adapter -n custom-metrics

# If workload identity is enabled, extra steps are required. We need to:
# - create a service account
# - grant it the monitoring.viewer IAM role
# - bind it to the workload identity user for the CMSA
# - annotate the CMSA service account (done above)
if [ "$WORKLOAD_IDENTITY" == "true" ]; then
    gcloud iam service-accounts create cmsa-sa
    gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:cmsa-sa@$PROJECT_ID.iam.gserviceaccount.com" --role=roles/monitoring.viewer
    gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:cmsa-sa@$PROJECT_ID.iam.gserviceaccount.com" --role=roles/iam.serviceAccountTokenCreator
    gcloud iam service-accounts add-iam-policy-binding --role roles/iam.workloadIdentityUser --member "serviceAccount:$PROJECT_ID.svc.id.goog[custom-metrics/custom-metrics-stackdriver-adapter]" "cmsa-sa@$PROJECT_ID.iam.gserviceaccount.com"
    kubectl annotate serviceaccount custom-metrics-stackdriver-adapter -n custom-metrics "iam.gke.io/gcp-service-account"="cmsa-sa@tpu-vm-gke-testing.iam.gserviceaccount.com"
fi

kubectl apply -f clusterrolebinding_custom-metrics:system:auth-delegator.yaml.tftpl
kubectl apply -f rolebinding_custom-metrics-auth-reader.yaml.tftpl
kubectl apply -f clusterrole_custom-metrics-resource-reader.yaml.tftpl
kubectl apply -f clusterrolebinding_custom-metrics-resource-reader.yaml.tftpl
kubectl apply -f deployment_custom-metrics-stackdriver-adapter.yaml.tftpl
kubectl apply -f service_custom-metrics-stackdriver-adapter.yaml.tftpl
kubectl apply -f apiservice_v1beta1.custom.metrics.k8s.io.yaml.tftpl
kubectl apply -f apiservice_v1beta2.custom.metrics.k8s.io.yaml.tftpl
kubectl apply -f apiservice_v1beta1.external.metrics.k8s.io.yaml.tftpl
kubectl apply -f clusterrolebinding_external-metrics-reader.yaml.tftpl
```

## Installation via Terraform

To use this as a module, include it from your terraform main:

```
module "custom_metrics_stackdriver_adapter" {
  source = "./path/to/custom-metrics-stackdriver-adapter"
}
```

For a workload identity enabled cluster, some additional configuration is
needed:

```
module "custom_metrics_stackdriver_adapter" {
  source = "./path/to/custom-metrics-stackdriver-adapter"
  workload_identity = {
    enabled = true
    project_id = "<PROJECT_ID>"
  }
}
```