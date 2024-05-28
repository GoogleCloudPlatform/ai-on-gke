import os
import pytest

from ..admission_controller import *

@pytest.fixture(autouse=True)
def clear_environ(mocker):
    """Clears environment variables before each test."""
    mocker.patch.dict('os.environ', clear=True)


def test_base_patch(mocker):
    """Tests the basic patch operation (adding job-key selector)."""
    object_in = {
        "kind": "Job",
        "metadata": {"name": "my-pod", "namespace": "default"},
        "spec": {"template": {"spec": {}}}
    }

    expected_patches = [
        NodeSelectorPatch(op="add", value={f"{job_key_label}": f"{job_key_value(object_in)}"}).dict()
    ]

    patches = make_patches(object_in)
    assert patches == expected_patches


def test_force_on_demand(mocker):
    """Tests patch operations when FORCE_ON_DEMAND is set."""
    mocker.patch.dict('os.environ', {FORCE_ON_DEMAND: "true"})

    object_in = {
        "kind": "Job",
        "metadata": {"name": "my-pod", "namespace": "default"},
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

    expected_patches = [
        NodeSelectorPatch(op="add", value={f"{job_key_label}": f"{job_key_value(object_in)}"}).dict(),
        NodeSelectorRemoval(path=f"/spec/template/spec/nodeSelector/{reservation_name_label}").dict(),
        NodeSelectorRemoval(path=f"/spec/template/spec/nodeSelector/{gke_spot_label}").dict(),
    ]

    patches = make_patches(object_in)
    assert patches == expected_patches

def test_location_hint_with_reservation(mocker):
    """Tests patch operations with LOCATION_HINT and using a reservation."""
    mocker.patch.dict('os.environ', {LOCATION_HINT: "cell"})

    object_in = {
        "kind": "JobSet",
        "metadata": {"name": "my-pod", "namespace": "default"},
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

    expected_patches = [
        NodeSelectorPatch(op="add", value={f"{job_key_label}": f"{job_key_value(object_in)}"}).dict(),
        NodeSelectorPatch(op="add", value={f"{gke_location_hint_label}": "cell"}).dict(),
    ]

    patches = make_patches(object_in)
    assert patches == expected_patches
