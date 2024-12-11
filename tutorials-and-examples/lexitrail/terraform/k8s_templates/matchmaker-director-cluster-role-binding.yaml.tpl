apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: fleet-allocator
  labels:
    app: fleet-allocator
    name: lexitrail-match-making-director
subjects:
  - kind: ServiceAccount
    name: fleet-allocator
    namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: fleet-allocator