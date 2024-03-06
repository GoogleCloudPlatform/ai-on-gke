apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${pv_name}
spec:
  storageClassName: ""
  capacity:
    storage: 12Ti
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  volumeMode: Filesystem
  csi:
    driver: parallelstore.csi.storage.gke.io
    volumeHandle: ${project}/${ps_location}/${ps_instance_name}/default-pool/default-container
    volumeAttributes:
      ip: "${ps_ip_address_1}, ${ps_ip_address_2}, ${ps_ip_address_3}"
      network: ${ps_network_name}