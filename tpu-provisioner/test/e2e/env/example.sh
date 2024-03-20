export PROJECT_ID="my-project"
export PROJECT_NUMBER="$(gcloud projects describe ${PROJECT_ID} --format='value(projectNumber)')"

export CONTROLLER_SA_NAME="tpu-provisioner"
export CONTROLLER_SA_EMAIL="${CONTROLLER_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

export REGION=us-central2
export ZONE=us-central2-b
export CLUSTER_NAME="tpu-provisioner-e2e"

export BUILD_TOOL="podman" # or "docker"

# Assumes you created a regional Google Artifact Registry instance.
export CONTROLLER_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/default/tpu-provisioner:$(git describe --tags --dirty --always)"

export NODE_SA_EMAIL="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
