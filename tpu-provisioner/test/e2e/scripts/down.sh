#!/bin/bash

set -e
set -x
set -u

if gcloud iam service-accounts describe $CONTROLLER_SA_EMAIL; then
    gcloud iam service-accounts delete $CONTROLLER_SA_EMAIL
fi

if gcloud container clusters describe --region $REGION $CLUSTER_NAME; then
    gcloud container clusters delete --region $REGION $CLUSTER_NAME
fi