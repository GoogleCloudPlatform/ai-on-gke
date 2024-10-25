## Populate a Hyperdisk ML Disk from Google Cloud Storage

1. Create a new GCE instance that you will use to hydrate the new Hyperdisk ML with data

```sh
VM_NAME=hydrator
MACHINE_TYPE=c3-standard-4
IMAGE_FAMILY=debian-11
IMAGE_PROJECT=debian-cloud
ZONE=us-central1-a
SNAP_SHOT_NAME=hdmlsnapshot
PROJECT_ID=myproject

DISK_NAME=model1

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
SIZE=140
THROUGHPUT=12000

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

5. Create a snapshot from the disk to use as a template

```sh
gcloud compute snapshots create $SNAP_SHOT_NAME \
    --source-disk-zone=$ZONE \
    --source-disk=$DISK_NAME \
    --project=$PROJECT_ID
```


6. You now have a hyperdisk ML volume populated with your data from Google Cloud Storage. You can delete the hydrator GCE instance

```sh
gcloud compute instances delete $VM_NAME \
--zone=$ZONE
```

7. To use this new Hyperdisk ML volume you first create your Hypedisk ML multi zone and standard Storage Classes. Hyperdisk ML disks are zonal and the Hyperdisk-ml-multi-zone storage class automatically provisions disks in zones where the pods using them are. 
Replace the zones in this class with the zones you want to allow the Hyperdisk ML snapshot to create disks in. 

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hyperdisk-ml-multi-zone
parameters:
  type: hyperdisk-ml
  provisioned-throughput-on-create: "2400Mi"
  enable-multi-zone-provisioning: "true"
provisioner: pd.csi.storage.gke.io
allowVolumeExpansion: false
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowedTopologies:
- matchLabelExpressions:
  - key: topology.gke.io/zone
    values:
    - us-central1-a
    - us-central1-c
--- 
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

7. You will then need to create a volumeSnapshotClass and VolumeSnapshotContent config to use your snapshot. Replace the VolumeSnapshotContent.spec.source.snapshotHandle with the path to your snapshot. 

```yaml

apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: my-snapshotclass
driver: pd.csi.storage.gke.io
deletionPolicy: Delete
---
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: restored-snapshot
spec:
  volumeSnapshotClassName: my-snapshotclass
  source:
    volumeSnapshotContentName: restored-snapshot-content
---
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotContent
metadata:
  name: restored-snapshot-content
spec:
  deletionPolicy: Retain
  driver: pd.csi.storage.gke.io
  source:
    snapshotHandle: projects/[project_ID]/global/snapshots/[snapshotname]
  volumeSnapshotRef:
    kind: VolumeSnapshot
    name: restored-snapshot
    namespace: default

```

8. Reference your snapshot in the following persistent volume claim. Be sure to adjust the spec.dataSource.name to your snapshot name

```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: hdml-consumer-pvc
spec:
  dataSource:
    name: restored-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
  - ReadOnlyMany
  storageClassName: hyperdisk-ml-multi-zone
  resources:
    requests:
      storage: 140Gi
```

8. You then add a reference to this PVC in your deployment spec.template.spec.volume.persistentVolumeClaim.claimName parameter. 

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ubuntu
  labels:
    app: ubuntu
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ubuntu
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: ubuntu
    spec:
      containers:
      - image: bkauf/storage:latest
        name: ubuntu
        command:
          - "sleep"
          - "604800"
        volumeMounts:
        - name: ubuntu-persistent-storage
          mountPath: /var/www/html
      volumes:
      - name: ubuntu-persistent-storage
        persistentVolumeClaim:
          claimName: hdml-consumer-pvc
```