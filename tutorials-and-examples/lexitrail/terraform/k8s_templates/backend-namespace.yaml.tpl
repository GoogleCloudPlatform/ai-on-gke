apiVersion: v1
kind: Namespace
metadata:
  name: ${backend_namespace}
  annotations:
    iam.gke.io/gcp-service-account: ${gsa_email}