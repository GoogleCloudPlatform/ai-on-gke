## Populate a Hyperdisk ML Disk from Google Cloud Storage

### This guide uses the Google Cloud API to create a Hyperdisk ML disk from data in Cloud Storage and then use it in a GKE cluster. Refer to [this documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/hyperdisk-ml) for instructions all in the GKE API

1. Create a new GCE instance that you will use to hydrate the new Hyperdisk ML disk with data. Note a c3-standard-44 instance is used to provide the max throughput while populating the hyperdisk([Instance to throughput rates](https://cloud.google.com/compute/docs/disks/hyperdisks#performance_limits_for_other_vms)).

```sh
VM_NAME=hydrator
MACHINE_TYPE=c3-standard-44
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

```
Update and authenticate the instance

```sh
sudo apt-get update
sudo apt-get install google-cloud-cli
gcloud init
gcloud auth login

```

2. Create and attach the disk to the new GCE VM.

```sh
SIZE=140
THROUGHPUT=2400

gcloud compute disks create $DISK_NAME --type=hyperdisk-ml \
--size=$SIZE --provisioned-throughput=$THROUGHPUT  \
--zone $ZONE

gcloud compute instances attach-disk $VM_NAME --disk=$DISK_NAME --zone=$ZONE 
```

3. Log into the hydrator VM, format the volume, initiate transfer, and dismount the volume.

```sh
gcloud compute ssh $VM_NAME
```

Mount and load the data from GCS
```sh 
% lsblk
# Save device name given by lsblk
DEVICE=nvme0n2
GCS_DIR=gs://vertex-model-garden-public-us-central1/llama2/llama2-70b-hf 
% sudo /sbin/mkfs -t ext4 -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/$DEVICE
 sudo mount $DEVICE /mnt
 gcloud storage cp -r $GCS_DIR /mnt
 sudo umount /mnt
```

4. Detach disk from the hydrator and switch to READ_ONLY_MANY access mode.
```sh
gcloud compute instances detach-disk $VM_NAME --disk=$DISK_NAME --zone=$ZONE
gcloud compute disks update $DISK_NAME --access-mode=READ_ONLY_MANY  --zone=$ZONE
```

5. Create a snapshot from the disk to use as a template.

```sh
gcloud compute snapshots create $SNAP_SHOT_NAME \
    --source-disk-zone=$ZONE \
    --source-disk=$DISK_NAME \
    --project=$PROJECT_ID
```

6. You now have a hyperdisk ML snapshot populated with your data from Google Cloud Storage. You can delete the hydrator GCE instance and the original disk.

```sh
gcloud compute instances delete $VM_NAME --zone=$ZONE
gcloud compute disks delete $DISK_NAME --project $PROJECT_ID --zone $ZONE
```

7. In your GKE cluster create your Hypedisk ML multi zone and standard Storage Classes. Hyperdisk ML disks are zonal and the Hyperdisk-ml-multi-zone storage class automatically provisions disks in zones where the pods using them are. 
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

7. Create a volumeSnapshotClass and VolumeSnapshotContent config to use your snapshot. Replace the VolumeSnapshotContent.spec.source.snapshotHandle with the path to your snapshot. 

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

8. Reference your snapshot in the persistent volume claim. Be sure to adjust the spec.dataSource.name to your snapshot name

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

8. Add a reference to this PVC in your deployment spec.template.spec.volume.persistentVolumeClaim.claimName parameter. 

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
      - image: busybox:latest
        name: ubuntu
        command:
          - "sleep"
          - "infinity"
        volumeMounts:
        - name: ubuntu-persistent-storage
          mountPath: /var/www/html
      volumes:
      - name: ubuntu-persistent-storage
        persistentVolumeClaim:
          claimName: hdml-consumer-pvc
```