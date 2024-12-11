apiVersion: v1
kind: Secret
metadata:
  name: backend-secret
  namespace: ${backend_namespace}
type: Opaque
data:
  DB_ROOT_PASSWORD: ${db_root_password}
