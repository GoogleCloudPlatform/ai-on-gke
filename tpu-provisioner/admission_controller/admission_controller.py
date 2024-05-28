import os
import logging
import base64
import json
import hashlib
from fastapi import FastAPI, Body
from pydantic import BaseModel
from datetime import datetime

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

# define data models
class NodeSelectorPatch(BaseModel):
    '''NodSelectorPatch represents an add or patch operation to the nodeSelector field of a Job's pod template.'''
    op: str
    path: str = "/spec/template/spec/nodeSelector"
    value: dict[str, str]

class NodeSelectorRemoval(BaseModel):
    '''NodSelectorRemoval represents a patch to remove the target node selector from a Job's pod template.'''
    op: str = "remove"
    path: str


# API endpoint
@app.post("/mutate")
def mutate_request(request: dict = Body(...)):
    '''API endpoint for the admission controller mutating webhook.'''
    uid = request["request"]["uid"]
    object_in = request["request"]["object"]

    webhook_logger.info(f'Patching {object_in["kind"]} {object_in["metadata"]["namespace"]}/{object_in["metadata"]["name"]}')

    return admission_review(uid, object_in)


def admission_review(uid: str, object_in: dict) -> dict:
    '''Returns an AdmissionReview JSONPatch as requried by the k8s apiserver.'''
    return {
        "apiVersion": "admission.k8s.io/v1",
        "kind": "AdmissionReview",
        "response": {
            "uid": uid,
            "allowed": True,
            "patchType": "JSONPatch",
            "status": {"message": f"Successfully patched {object_in['kind']}: {object_in['metadata']['namespace']}/{object_in['metadata']['name']}"},
            "patch": patch(object_in),
        },
    }


def patch(object_in: dict) -> str:
    '''Returns a base64 encoded patch for the given k8s object.'''
    patches: list[dict] = make_patches(object_in)
    return base64.b64encode(json.dumps(patches).encode()).decode()


def make_patches(object_in: dict) -> str:
    '''Returns a list of NodeSelectorPatch objects for the given k8s object.'''
    job_name: str = object_in["metadata"]["name"]

    # add job-key selector
    patch_operations: list[dict] = [
        NodeSelectorPatch(op="add", value={f"{job_key_label}": f"{job_key_value(object_in)}"}).dict()
    ]
    webhook_logger.info(f'Job: {job_name} Added nodeSelector: {job_key_label}: {job_key_value(object_in)}')

    # handle FORCE_ON_DEMAND
    if os.environ.get(FORCE_ON_DEMAND) == "true":
        patch_operations.extend([
           NodeSelectorRemoval(path=f"/spec/template/spec/nodeSelector/{reservation_name_label}").dict(),
           NodeSelectorRemoval(path=f"/spec/template/spec/nodeSelector/{gke_spot_label}").dict(),
        ])
        webhook_logger.info(f'Job: {job_name} Removed nodeSelector for node label: {reservation_name_label}')
        webhook_logger.info(f'Job: {job_name} Removed nodeSelector for node label: {gke_spot_label}')

    # handle RESERVATION_LOCATION_HINT and ALWAYS_HINT_TIME
    location_hint_value: str = os.environ.get(LOCATION_HINT, "")
    if location_hint_value != "":
        patch_operations.append(
            NodeSelectorPatch(op="add", value={f"{gke_location_hint_label}": f"{location_hint_value}"}).dict()
        )
        webhook_logger.info(f'Job: {job_name} Added nodeSelector: {gke_location_hint_label}: {location_hint_value}')

    return patch_operations


def job_key_value(object_in: dict) -> str:
    '''Returns the SHA1 hash of the namespaced Job name.'''
    job_namespace: str = object_in["metadata"]["namespace"]
    job_name: str = object_in["metadata"]["name"]
    return sha1(f'{job_namespace}/{job_name}')


def sha1(data: str) -> str:
    '''Returns the SHA1 hash of the given string.'''
    return hashlib.sha1(data.encode()).hexdigest()
