#!/bin/bash

CURRENT_DIR="$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)"

set -o pipefail

# The name of the example driver
: ${DRIVER_NAME:=tpu-dra-driver}

# The registry, image and tag for the example driver
# Please update DRIVER_IMAGE_REGISTRY
: ${DRIVER_IMAGE_REGISTRY:="gcr.io/gke-release-staging"}
: ${DRIVER_IMAGE_NAME:="${DRIVER_NAME}"}
: ${DRIVER_IMAGE_TAG:="master.0"}
: ${DRIVER_IMAGE_PLATFORM:="ubuntu22.04"}

# The derived name of the driver image to build
: ${DRIVER_IMAGE:="${DRIVER_IMAGE_REGISTRY}/${DRIVER_IMAGE_NAME}:${DRIVER_IMAGE_TAG}"}

helm upgrade -i --create-namespace --namespace tpu-dra-driver tpu-dra-driver ${CURRENT_DIR} \
  --set image.repository=${DRIVER_IMAGE_REGISTRY}/${DRIVER_IMAGE_NAME} \
  --set image.tag=${DRIVER_IMAGE_TAG} \
  --set image.pullPolicy=Always \
  --set cdi.enabled=true \
  --set cdi.default=true \
  --set controller.priorityClassName="" \
  --set kubeletPlugin.priorityClassName="" \
  --set deviceClasses="{tpu}" \
