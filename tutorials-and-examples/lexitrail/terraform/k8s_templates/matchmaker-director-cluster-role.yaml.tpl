apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fleet-allocator
  labels:
    app: fleet-allocator
    name: lexitrail-match-making-director
rules:
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create"]
  - apiGroups: ["allocation.agones.dev"]
    resources: ["gameserverallocations"]
    verbs: ["create"]
  - apiGroups: ["agones.dev"]
    resources: ["fleets"]
    verbs: ["get"]