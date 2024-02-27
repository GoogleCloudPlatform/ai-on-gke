#!/bin/bash

set -o errexit

cd ../inference-server/text-generation-inference/ || exit
terraform destroy -auto-approve

cd ../../infra/stage-2/ || exit
terraform destroy -auto-approve

cd ../stage-1/ || exit
terraform destroy -auto-approve
