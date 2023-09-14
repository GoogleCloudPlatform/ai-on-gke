
```
export PROJECT_ID=$(gcloud config get project)
export REGION=us-central1
export BUCKET_NAME=${PROJECT_ID}-llama-l4
export SERVICE_ACCOUNT="l4-demo@${PROJECT_ID}.iam.gserviceaccount.com"
export IMAGE=gcr.io/$PROJECT_ID/vllm

gcloud container clusters create l4-demo --location ${REGION} \
  --workload-pool ${PROJECT_ID}.svc.id.goog \
  --enable-image-streaming --enable-shielded-nodes \
  --shielded-secure-boot --shielded-integrity-monitoring \
  --enable-ip-alias \
  --node-locations=$REGION-a \
  --workload-pool=${PROJECT_ID}.svc.id.goog \
  --addons GcsFuseCsiDriver   \
  --no-enable-master-authorized-networks \
  --machine-type n2d-standard-4 \
  --num-nodes 1 --min-nodes 1 --max-nodes 5 \
  --ephemeral-storage-local-ssd=count=2 \
  --enable-ip-alias \
  --enable-private-nodes  \
  --master-ipv4-cidr 172.16.0.32/28

gcloud container node-pools create g2-standard-48 --cluster l4-demo \
  --accelerator type=nvidia-l4,count=4,gpu-driver-version=latest \
  --machine-type g2-standard-48 \
  --ephemeral-storage-local-ssd=count=4 \
  --enable-autoscaling --enable-image-streaming \
  --num-nodes=0 --min-nodes=0 --max-nodes=3 \
  --shielded-secure-boot \
  --shielded-integrity-monitoring \
  --node-locations $REGION-a,$REGION-b --region $REGION --spot

gcloud container node-pools create g2-standard-96 --cluster l4-demo \
  --accelerator type=nvidia-l4,count=8,gpu-driver-version=latest \
  --machine-type g2-standard-96 \
  --ephemeral-storage-local-ssd=count=8 \
  --enable-autoscaling --enable-image-streaming \
  --num-nodes=0 --min-nodes=0 --max-nodes=3 \
  --shielded-secure-boot \
  --shielded-integrity-monitoring \
  --node-locations $REGION-a,$REGION-b --region $REGION --spot

gcloud builds submit -t $IMAGE .
```