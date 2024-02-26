#!/bin/bash

set -e
set -x
set -u

echo "Build tool: ${BUILD_TOOL}"
echo "Controller image: ${CONTROLLER_IMAGE}"
echo "Node service account: ${NODE_SA_EMAIL}"
echo "Controller service account: ${CONTROLLER_SA_EMAIL}"

repo_root=$(git rev-parse --show-toplevel)
root_dir="${repo_root}/tpu-provisioner"

${BUILD_TOOL} build --platform linux/amd64 -t ${CONTROLLER_IMAGE} ${root_dir}
${BUILD_TOOL} push ${CONTROLLER_IMAGE}

kustomize build ${root_dir}/test/e2e/config | envsubst | kubectl apply --server-side -f -
# Restart Pods is already running
kubectl delete pods -n tpu-provisioner-system --all

go clean -testcache

cd ${root_dir}/test/e2e/test ; go test -v . ; cd -