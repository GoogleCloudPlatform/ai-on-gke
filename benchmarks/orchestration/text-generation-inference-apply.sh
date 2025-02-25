#!/bin/bash

set -o errexit

cd ../infra/accelerator-cluster/stage-1/ || exit
cp ../../../orchestration/config/stage-1.tfvars ./terraform.tfvars
terraform init -upgrade
terraform apply -auto-approve
FLEET_HOST=$(terraform output -json | jq '."fleet_host".value')
PROJECT_ID=$(terraform output -json | jq '."project_id".value')

cd ../stage-2/ || exit
cp ../../../orchestration/config/stage-2.tfvars ./terraform.tfvars
cp ../../../orchestration/templates/stage-2.auto.tfvars.tpl ./stage-2.auto.tfvars
sed -i "s@FLEET_HOST@${FLEET_HOST}@g" ./stage-2.auto.tfvars
sed -i "s@PROJECT_ID@${PROJECT_ID}@g" ./stage-2.auto.tfvars
terraform init -upgrade
terraform apply -auto-approve
HUGGING_FACE_SECRET=$(terraform output -json created_resources | jq '.. | .hugging_face_secret? | values')
NAMESPACE_NAME=$(terraform output -json created_resources | jq '.. | .namespace_name? | values')
KSA_NAME=$(terraform output -json created_resources | jq '.. | .ksa_name? | values')

cd ../../../inference-server/text-generation-inference/ || exit
cp ../../orchestration/config/text-generation-inference.tfvars ./terraform.tfvars
cp ../../orchestration/templates/text-generation-inference.auto.tfvars.tpl ./text-generation-inference.auto.tfvars
sed -i "s@FLEET_HOST@${FLEET_HOST}@g" ./text-generation-inference.auto.tfvars
sed -i "s@PROJECT_ID@${PROJECT_ID}@g" ./text-generation-inference.auto.tfvars
sed -i "s@HUGGING_FACE_SECRET@${HUGGING_FACE_SECRET}@g" ./text-generation-inference.auto.tfvars
sed -i "s@NAMESPACE_NAME@${NAMESPACE_NAME}@g" ./text-generation-inference.auto.tfvars
sed -i "s@KSA_NAME@${KSA_NAME}@g" ./text-generation-inference.auto.tfvars
terraform init -upgrade
terraform apply -auto-approve
