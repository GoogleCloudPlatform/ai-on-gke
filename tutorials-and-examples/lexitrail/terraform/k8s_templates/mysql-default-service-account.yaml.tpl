apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
  namespace: ${sql_namespace}
  annotations:
    iam.gke.io/gcp-service-account: ${gsa_email}
