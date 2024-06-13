#!/bin/bash

set -e
set -x
set -u
set -o pipefail

this_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

function clean_up {
  echo "Cleaning up"
  kubectl delete --ignore-not-found -f $this_dir/manifests/
}
trap clean_up EXIT

kubectl create -f $this_dir/manifests/

echo "Waiting for Jobs to be created..."
sleep 3

function job_has_selector_len {
    key_val=$(kubectl get job $3 -ojsonpath="{.spec.template.spec.nodeSelector.$2}")
    if [[ ${#key_val} == $1 ]]; then
        echo "PASS: Job has node selector "$2" with correct length."
    else
        echo "FAIL: Job node selector "$2" has the wrong length!"
        exit 1
    fi
}

job_has_selector_len 40 job-key test-jobset-location-hint-no-reservation-workers-0
job_has_selector_len 40 job-key test-jobset-location-hint-with-reservation-workers-0
job_has_selector_len  0 job-key test-disabled-provisioning-workers-0
job_has_selector_len  0 job-key test-nonjobset-job

job_has_selector_len  4 'cloud\.google\.com/gke-location-hint' test-jobset-location-hint-no-reservation-workers-0
job_has_selector_len  4 'cloud\.google\.com/gke-location-hint' test-jobset-location-hint-with-reservation-workers-0
job_has_selector_len  0 'cloud\.google\.com/gke-location-hint' test-disabled-provisioning-workers-0
job_has_selector_len  0 'cloud\.google\.com/gke-location-hint' test-nonjobset-job

echo "SUCCESS"