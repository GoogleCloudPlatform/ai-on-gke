apiVersion: v1
kind: Namespace
metadata:
  name: ${sql_namespace}
  annotations:
    iam.gke.io/gcp-service-account: ${gsa_email}
