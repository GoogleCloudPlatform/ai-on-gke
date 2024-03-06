kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: ${pvc_name}
  namespace: ${namespace}
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ${storageclass}
  volumeName: ${pv_name}
  resources:
    requests:
      storage: 12000Gi