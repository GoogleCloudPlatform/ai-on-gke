#!/usr/bin/env python3 
import os
import json
import base64
import logging
import hashlib
from fastapi import FastAPI, Body
from jsonpatch import JsonPatch
from copy import deepcopy

app = FastAPI()

webhook_logger = logging.getLogger(__name__)
webhook_logger.setLevel(logging.INFO)
logging.basicConfig(format="[%(asctime)s] %(levelname)s: %(message)s")

# environment variables
LOCATION_HINT = "RESERVATION_LOCATION_HINT"
ALWAYS_HINT_TIME = "ALWAYS_HINT_TIME"
FORCE_ON_DEMAND = "FORCE_ON_DEMAND"

# labels
job_key_label = "job-key"
reservation_name_label = "cloud.google.com/reservation-name"
gke_spot_label = "cloud.google.com/gke-spot"
gke_location_hint_label = "cloud.google.com/gke-location-hint"

# API endpoint
@app.post("/mutate")
def mutate_request(request: dict = Body(...)):
    '''API endpoint for the admission controller mutating webhook.'''
    uid: str = request["request"]["uid"]

    object_in: dict = request["request"]["object"]
    webhook_logger.info(f'Patching {object_in["kind"]} {object_in["metadata"]["namespace"]}/{object_in["metadata"]["name"]}')

    response: dict = admission_review(uid, object_in)
    webhook_logger.info(f'Response: {json.dumps(response)}')
    return response


def admission_review(uid: str, object_in: dict) -> dict:
    '''Returns an AdmissionReview JSONPatch for the given AdmissionRequest.'''
    return {
        "apiVersion": "admission.k8s.io/v1",
        "kind": "AdmissionReview",
        "response": {
            "uid": uid,
            "allowed": True,
            "patchType": "JSONPatch",
            "status": {"message": f"Patched {object_in['kind']}: {object_in['metadata']['namespace']}/{object_in['metadata']['name']}"},
            "patch": patch(object_in),
        },
    }


def patch(object_in: dict) -> str:
    '''Returns a base64 encoded patch for the given k8s object.'''
    patches: list[dict] = make_patches(object_in)
    return base64.b64encode(str(patches).encode()).decode()


def make_patches(object_in: dict) -> JsonPatch:
    '''Generates a JsonPatch for Job mutations that are based on environment variables.'''
    job_name: str = object_in["metadata"]["name"]
    job_namespace: str = object_in["metadata"]["namespace"]
    modified_object: dict = deepcopy(object_in)

    if "nodeSelector" not in modified_object["spec"]["template"]["spec"]:
        modified_object["spec"]["template"]["spec"]["nodeSelector"] = {}

    # Add job-key node selector unconditionally.
    modified_object["spec"]["template"]["spec"]["nodeSelector"][job_key_label] = job_key_value(job_name, job_namespace)
    webhook_logger.info(f'Job: {job_name} Added nodeSelector: {job_key_label}: {job_key_value(job_name, job_namespace)}')

    if os.environ.get(FORCE_ON_DEMAND) == "true":
        # Remove reservation label if FORCE_ON_DEMAND is set.
        if reservation_name_label in modified_object["spec"]["template"]["spec"]["nodeSelector"]:
            del modified_object["spec"]["template"]["spec"]["nodeSelector"][reservation_name_label]
            webhook_logger.info(f'Job: {job_name} Removed nodeSelector for node label: {reservation_name_label}')
        # Remove spot label if FORCE_ON_DEMAND is set.
        if gke_spot_label in modified_object["spec"]["template"]["spec"]["nodeSelector"]:
            del modified_object["spec"]["template"]["spec"]["nodeSelector"][gke_spot_label]
            webhook_logger.info(f'Job: {job_name} Removed nodeSelector for node label: {gke_spot_label}')

    # Set location hint nodeSelector if RESERVATION_LOCATION_HINT is set.
    location_hint_value: str = os.environ.get(LOCATION_HINT, "")
    if location_hint_value != "":
        modified_object["spec"]["template"]["spec"]["nodeSelector"][gke_location_hint_label] = location_hint_value
        webhook_logger.info(f'Job: {job_name} Added nodeSelector: {gke_location_hint_label}: {location_hint_value}')

    patch: JsonPatch = JsonPatch.from_diff(object_in, modified_object)
    return patch


def job_key_value(job_name: str, job_namespace: str) -> str:
    '''Returns the SHA1 hash of the namespaced Job name.'''
    return sha1(f'{job_namespace}/{job_name}')


def sha1(data: str) -> str:
    '''Returns the SHA1 hash of the given string.'''
    return hashlib.sha1(data.encode()).hexdigest()
