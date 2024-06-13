import os
import pytest
from jsonpatch import JsonPatch    

from ..admission_controller import *

test_job_name = "test-job" 
test_job_ns = "default" 

# RFC 6901: escaped forward slash '/' in JSONPatch is encoded as '~1': https://datatracker.ietf.org/doc/html/rfc6901#section-3
escaped_reservation_label = reservation_name_label.replace('/', '~1')
escaped_gke_spot_label = gke_spot_label.replace('/', '~1')
escaped_gke_location_hint_label = gke_location_hint_label.replace('/', '~1')

@pytest.fixture(autouse=True)
def clear_environ(mocker):
    """Clears environment variables before each test."""
    mocker.patch.dict('os.environ', clear=True)


def test_base_patch_existing_nodeselector(mocker):
    """Tests the basic patch operation (adding job-key selector)."""
    object_in = {
        "kind": "Job",
        "metadata": {"name": test_job_name, "namespace": test_job_ns},
        "spec": {"template": {"spec": {"nodeSelector": {"test-key": "test-value"}}}}
    }

    expected_patches = JsonPatch([
        {'op': 'add', 'path': f'/spec/template/spec/nodeSelector/{job_key_label}', 'value': job_key_value(test_job_name, test_job_ns)},
    ])

    patches = make_patches(object_in)
    assert ordered(patches.patch) == ordered(expected_patches.patch)


def test_base_patch_empty_nodeselector(mocker):
    """Tests the basic patch operation (adding job-key selector)."""
    object_in = {
        "kind": "Job",
        "metadata": {"name": test_job_name, "namespace": test_job_ns},
        "spec": {"template": {"spec": {}}}
    }

    expected_patches = JsonPatch([
        {'op': 'add', 'path': f'/spec/template/spec/nodeSelector', 'value': {job_key_label: job_key_value(test_job_name, test_job_ns)}},
    ])
    patches = make_patches(object_in)
    assert ordered(patches.patch) == ordered(expected_patches.patch)


def test_force_on_demand(mocker):
    """Tests patch operations when FORCE_ON_DEMAND is set."""
    mocker.patch.dict('os.environ', {FORCE_ON_DEMAND: "true"})

    object_in = {
        "kind": "Job",
        "metadata": {"name": test_job_name, "namespace": test_job_ns},
        "spec": {
            "template": {
                "spec": {
                    "nodeSelector": {
                        gke_spot_label: "true",
                        reservation_name_label: "my-reservation",
                    }
                }
            }
        }
    }

    expected_patches = JsonPatch([
        {'op': 'add', 'path': f'/spec/template/spec/nodeSelector/{job_key_label}', 'value': job_key_value(test_job_name, test_job_ns)},
        {'op': 'remove', 'path': f'/spec/template/spec/nodeSelector/{escaped_reservation_label}'},
        {'op': 'remove', 'path': f'/spec/template/spec/nodeSelector/{escaped_gke_spot_label}'},
    ])

    patches = make_patches(object_in)
    assert ordered(patches.patch) == ordered(expected_patches.patch)


def test_location_hint_with_reservation(mocker):
    """Tests patch operations with LOCATION_HINT and using a reservation."""
    mocker.patch.dict('os.environ', {LOCATION_HINT: "cell"})

    object_in = {
        "kind": "JobSet",
        "metadata": {"name": test_job_name, "namespace": test_job_ns},
        "spec": {
            "template": {
                "spec": {
                    "nodeSelector": {
                        reservation_name_label: "my-reservation",
                    }
                }
            }
        }
    }

    expected_patches = JsonPatch([
        {'op': 'add', 'path': f'/spec/template/spec/nodeSelector/{job_key_label}', 'value': job_key_value(test_job_name, test_job_ns)},
        {'op': 'add', 'path': f'/spec/template/spec/nodeSelector/{escaped_gke_location_hint_label}', 'value': 'cell'},
    ])

    patches = make_patches(object_in)
    assert ordered(patches.patch) == ordered(expected_patches.patch)


def ordered(obj):
    '''Recursively sort a dictionary or list of dictionaries.
    Used for equality comparison of two JSON objects.'''
    if isinstance(obj, dict):
        return sorted((k, ordered(v)) for k, v in obj.items())
    if isinstance(obj, list):
        return sorted(ordered(x) for x in obj)
    else:
        return obj