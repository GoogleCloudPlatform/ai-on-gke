export PROJECT_ID=<your-project-id>

export REGION=us-east1
export ZONE_1=${REGION}-c # You may want to change the zone letter based on the region you selected above

export CLUSTER_NAME=gpu-autoscale
gcloud config set project "$PROJECT_ID"
gcloud config set compute/region "$REGION"
gcloud config set compute/zone "$ZONE_1"

gcloud container clusters create $CLUSTER_NAME --location ${REGION} \
  --workload-pool ${PROJECT_ID}.svc.id.goog \
  --enable-image-streaming --enable-shielded-nodes \
  --shielded-secure-boot --shielded-integrity-monitoring \
  --enable-ip-alias \
  --node-locations=$REGION-b \
  --workload-pool=${PROJECT_ID}.svc.id.goog \
  --addons GcsFuseCsiDriver   \
  --no-enable-master-authorized-networks \
  --machine-type n2d-standard-4 \
  --cluster-version 1.29 \
  --num-nodes 1 --min-nodes 1 --max-nodes 3 \
  --ephemeral-storage-local-ssd=count=2 \
  --scopes="gke-default,storage-rw"

#TPU:

gcloud container node-pools create $CLUSTER_NAME-tpu \
--location=$REGION --cluster=$CLUSTER_NAME --node-locations=$ZONE_1 \
--machine-type=ct5lp-hightpu-1t --num-nodes=0 --spot --node-version=1.29 \
--ephemeral-storage-local-ssd=count=0 --enable-image-streaming \
--shielded-secure-boot --shielded-integrity-monitoring \
--enable-autoscaling --total-min-nodes 0 --total-max-nodes 2 --location-policy=ANY