apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${pv_name}
spec:
  accessModes:
  - ReadWriteMany
  capacity:
    # This is a placeholder, can be any number. It needs to match with the PVC resource.requests.storage field
    storage: 1Gi
  persistentVolumeReclaimPolicy: Retain
  storageClassName: dummy-storage-class
  mountOptions:
  - stat-cache-capacity=${gcsfuse_stat_cache_capacity}
  - stat-cache-ttl=${gcsfuse_stat_cache_ttl}
  - type-cache-ttl=${gcsfuse_type_cache_ttl}
  claimRef:
    namespace: ${namespace}
    name: ${pvc_name}
  csi:
    driver: gcsfuse.csi.storage.gke.io
    volumeHandle: ${gcs_bucket} # unique bucket name