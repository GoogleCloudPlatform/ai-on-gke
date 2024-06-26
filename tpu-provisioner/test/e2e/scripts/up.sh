#!/bin/bash

set -e
set -x
set -u

echo "Project ID: ${PROJECT_ID}"

if ! gcloud iam service-accounts describe $CONTROLLER_SA_EMAIL; then
    gcloud iam service-accounts create $CONTROLLER_SA_NAME
    
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:${CONTROLLER_SA_EMAIL}" \
        --role='roles/container.clusterAdmin'

	gcloud iam service-accounts add-iam-policy-binding ${CONTROLLER_SA_EMAIL} \
	    --role roles/iam.workloadIdentityUser \
	    --member "serviceAccount:${PROJECT_ID}.svc.id.goog[tpu-provisioner-system/tpu-provisioner-controller-manager]"

	gcloud iam service-accounts add-iam-policy-binding ${NODE_SA_EMAIL} \
	    --role roles/iam.serviceAccountUser \
	    --member "serviceAccount:${CONTROLLER_SA_EMAIL}"
fi

if ! gcloud container clusters describe --region $REGION $CLUSTER_NAME; then
    gcloud container clusters create $CLUSTER_NAME \
    	--shielded-secure-boot \
        --shielded-integrity-monitoring \
    	--region $REGION \
    	--machine-type n2-standard-4 \
    	--num-nodes 1 \
    	--enable-ip-alias \
    	--release-channel rapid \
    	--workload-pool $PROJECT_ID.svc.id.goog \
    	--enable-image-streaming
else
	gcloud container clusters get-credentials --region $REGION $CLUSTER_NAME
fi

kubectl apply --server-side -f https://github.com/kubernetes-sigs/jobset/releases/download/v0.3.2/manifests.yaml