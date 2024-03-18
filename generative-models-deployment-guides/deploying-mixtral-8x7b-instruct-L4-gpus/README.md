


#### Deploy Base Cluster:
gcloud container clusters create mistral-cluster-gke  \
    --location=${REGION} \
    --node-locations=${REGION} \
    --project= ${PROJECT_ID} \
    --machine-type=n1-standard-4 \
    --no-enable-master-authorized-networks \
    --addons=GcsFuseCsiDriver \
    --num-nodes=5 \
    --min-nodes=1 \
    --max-nodes=5 \
    --enable-ip-alias \
    --enable-image-streaming \
    --enable-shielded-nodes \
    --shielded-secure-boot \
    --shielded-integrity-monitoring \
    --workload-pool=${WORKLOAD_POOL}.svc.id.goog
