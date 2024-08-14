apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${latency_profile_kubernetes_service_account}
  namespace: ${namespace}
  annotations:
    iam.gke.io/gcp-service-account: "${google_service_account}@tpu-vm-gke-testing.iam.gserviceaccount.com"