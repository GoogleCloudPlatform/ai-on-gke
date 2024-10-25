## Populate a Hyperdisk ML Disk from Google Cloud Storage

1. Create a new GCE instance that you will use to hydrate the new Hyperdisk ML with data


```sh
VM_NAME=hydrator
MACHINE_TYPE=c3-standard-4
IMAGE_FAMILY=debian-11
IMAGE_PROJECT=debian-cloud
ZONE=us-central1-a

gcloud compute instances create $VM_NAME \
    --image-family=$IMAGE_FAMILY \
    --image-project=$IMAGE_PROJECT \
    --zone=$ZONE \
    --machine-type=$MACHINE_TYPE

gcloud compute ssh $VM_NAME

% sudo apt-get update
% sudo apt-get install google-cloud-cli
% gcloud init
% gcloud auth login

```

2. Create and attach the disk to the new GCE VM

```sh
DISK_NAME=model1
SIZE=140
THROUGHPUT=12000
ZONE=us-central1-a

gcloud compute disks create $DISK_NAME --type=hyperdisk-ml \
 --size=$SIZE --provisioned-throughput=$THROUGHPUT  \
--zone $ZONE

gcloud compute instances attach-disk $VM_NAME --disk=$DISK_NAME --zone=$ZONE 
```

3. Log into the hydrator, format the volume, initiate transfer, and dismount the volume

```sh
gcloud compute ssh $VM_NAME

% lsblk
# Save device name given by lsblk
DEVICE=nvme0n2
GCS_DIR=gs://vertex-model-garden-public-us-central1/llama2/llama2-70b-hf 
% sudo /sbin/mkfs -t ext4 -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/$DEVICE
% sudo mount $DEVICE /mnt

% gcloud storage cp -r $GCS_DIR /mnt

% sudo umount /mnt
```

4. Detach disk from the hydrator and switch to READ_ONLY_MANY access mode
```sh
gcloud compute instances detach-disk $VM_NAME --disk=$DISK_NAME --zone=$ZONE
gcloud compute disks update $DISK_NAME --access-mode=READ_ONLY_MANY  --zone=$ZONE
```

5. You now have a hyperdisk ML volume populated with your data from Google Cloud Storage. You can delete the hydrator GCE instance

```sh
gcloud compute instances delete $VM_NAME \
--zone=$ZONE
```

6. To use this new Hyperdisk ML volume you first create your Hypedisk ML Storage Class

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
    name: hyperdisk-ml
parameters:
    type: hyperdisk-ml
provisioner: pd.csi.storage.gke.io
allowVolumeExpansion: false
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

7. You can then reference this volume to your PVC spec replacing the spec.csi.volumeHandle with the patch to your DISK_NAME

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hdml-static-pv
spec:
  storageClassName: "hyperdisk-ml"
  capacity:
    storage: 300Gi
  accessModes:
    - ReadOnlyMany
  claimRef:
    namespace: default
    name: hdml-static-pvc
  csi:
    driver: pd.csi.storage.gke.io
    volumeHandle: projects/PROJECT/zones/ZONE/disks/DISK_NAME
    fsType: ext4
    readOnly: true
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: topology.gke.io/zone
          operator: In
          values:
          - ZONE
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  namespace: default
  name: hdml-static-pvc
spec:
  storageClassName: "hyperdisk-ml"
  volumeName: hdml-static-pv
  accessModes:
  - ReadOnlyMany
  resources:
    requests:
      storage: 300Gi
```
8. You then add a reference to this PVC in your Deployment Spec
 Example:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-gemma-deployment
spec:
  ...
  template:
    ...
    spec:
      ...
      containers:
      ...
      volumes:
      - name: gemma-7b
        persistentVolumeClaim:
          claimName: CLAIM_NAME
```