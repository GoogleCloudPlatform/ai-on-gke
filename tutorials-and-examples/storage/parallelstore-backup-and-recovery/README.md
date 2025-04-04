# Data backup and recovery for Parallelstore

## Data Backup

### Prerequisites

Follow the instructions in [Create and connect to a Parallelstore instance from Google Kubernetes Engine](https://cloud.google.com/parallelstore/docs/connect-from-kubernetes-engine) to create a GKE cluster with Parallelstore enabled.

### Connect to your GKE cluster

```
gcloud container clusters get-credentials $CLUSTER_NAME --zone $CLUSTER_ZONE --project $PROJECT_ID
```

### Provision required permissions

Your GKE CronJob needs **roles/parallelstore.admin** and **roles/storage.admin** role to import and export data between GCS and ParallelStore.

#### Create GCP Service Account IAM SA

```
gcloud iam service-accounts create parallelstore-sa \
    --project=$PROJECT_ID
```

#### Grant GCP Service Account with ParallelStore admin and GCS admin role

```
gcloud projects add-iam-policy-binding $PROJECT_ID \
   --member "serviceAccount:parallelstore-sa@$PROJECT_ID.iam.gserviceaccount.com" \
   --role "roles/parallelstore.admin" 
gcloud projects add-iam-policy-binding $PROJECT_ID \
   --member "serviceAccount:parallelstore-sa@$PROJECT_ID.iam.gserviceaccount.com" \
   --role "roles/storage.admin"
```

#### Create GKE Service Account and allow it to impersonate GCP Service Account

```
kubeclt apply -f ./parallelstore-sa.yaml
```

##### Bind the GCP SA and GKE SA

```
gcloud iam service-accounts add-iam-policy-binding parallelstore-sa@$PROJECT_ID.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:$PROJECT_ID.svc.id.goog[default/parallelstore-sa]"
```

##### Annotate the GKE SA with GCP SA

```
kubectl annotate serviceaccount parallelstore-sa \
    --namespace default \ iam.gke.io/gcp-service-account=parallelstore-sa@my-project.iam.gserviceaccount.com
```

#### Grant permission to ParallelStore Agent Service Account

* GCS_BUCKET:  ***The GCS bucket URI in the format of “gs://<bucket_name>”***

```
gcloud storage buckets add-iam-policy-binding $GCS_BUCKET \
  --member=serviceAccount:service-$PROJECT_NUMBER@gcp-sa-parallelstore.iam.gserviceaccount.com \
  --role=roles/storage.admin 
```

### Cronjob for periodically export data from Parallelstore to GCS

Update the below Variable base on your workload set up and deploy the Cronjob to your cluster.

* PSTORE_MOUNT_PATH:  `e.g. "/data-ps"`  ***The mount path of the Parallelstore Instance, should match the volumeMount defined for this container***

* PSTORE_PV_NAME: `e.g. "store-pv"` ***The name of the GKE Persistent Volume that points to your Parallelstore Instance. This should have been set up in your cluster as part of the prerequisites***

* PSTORE_PVC_NAME: `e.g. "pstore-pvc"` ***The name of the GKE Persistent Volume Claim that requests the usage of the Parallelstore Persistent Volume. This should have been set up in your cluster as part of the prerequisites***

* PSTORE_NAME: `e.g. "checkpoints-ps"` ***The name of the Parallelstore Instance that need backup***

* PSTORE_LOCATION: `e.g. "us-central1-a"` ***The location/zone of the Parallelstore Instance that need backup***

* SOURCE_PARALLELSTORE_PATH: `e.g. "/nemo-experiments/user-model-workload-ps-64/checkpoints/". ***The absolute path from the Parallelstore instance, WITHOUT volume mount path, must start with “/”***

* DESTINATION_GCS_URI: `e.g. "gs://checkpoints-gcs/checkpoints/"` ***The GCS bucket path URI to a Cloud Storage bucket, or a path within a bucket, using the format "gs://<bucket_name>/<optional_path_inside_bucket>"***

* DELETE_AFTER_BACKUP: `e.g. false` ***Whether to delete old data from Parallelstore after backup and free up space***

```
kubeclt apply -f ./ps-to-gcs-backup.yaml
```

## Data Recovery

When disaster happens or the ParallelStore instance fails for any reason, you can either use the GKE Volume Populator to automatically preload data from GCS into a fully managed ParallelStore instance, or manually create a new ParallelStore Instance and import data from GCS backup.

### GKE Volume Populator

Detail instruction of how to use GKE Volume Populator to preload data into a new ParallelStore instance can be found in [Transfer data from Cloud Storage during dynamic provisioning using GKE Volume Populator ](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/volume-populator#preload-parallelstore)

### Manual recovery

* PARALLELSTORE_NAME ***The name of this Parallelstore instance***
CAPACITY_GB ***Storage capacity of the instance in GB, value from 12000 to 100000, in multiples of 4000***

* PARALLELSTORE_LOCATION ***Must be one of the Supported locations***

* NETWORK_NAME ***The name of the VPC network that you created in Configure a VPC network, must be the same network your GKE cluster uses and have private services access enabled***

* SOURCE_GCS_PATH: ***The GCS bucket path URI to a Cloud Storage bucket, or a path within a bucket, using the format "gs://<bucket_name>/<optional_path_inside_bucket>"***

* DESTINATION_PARALLELSTORE_URI: ***The absolute path from the Parallelstore instance, WITHOUT volume mount path, must start with “/”***

#### Create a new Parallelstore Instance
```
gcloud beta parallelstore instances create $PARALLELSTORE_NAME \
  --capacity-gib=$CAPACITY_GB \
  --location=$PARALLELSTORE_LOCATION \
  --network=$NETWORK_NAME \
  --project=$PROJECT_ID
```

#### Import data from GCS
```
uuid=$(cat /proc/sys/kernel/random/uuid) # generate a uuid for the parallelstore data import request-id

gcloud beta parallelstore instances import-data $PARALLELSTORE_NAME \
  --location=$PARALLELSTORE_LOCATION \
  --source-gcs-bucket-uri=$SOURCE_GCS_PATH \
  --destination-parallelstore-path=$DESTINATION_PARALLELSTORE_URI \
  --request-id=$uuid \
  --async
```
