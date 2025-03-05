import pytest
from utils.kubernetes_helpers import load_yaml_manifest

@pytest.fixture
def job_manifest():
    return load_yaml_manifest('pretraining/job.yaml')

def test_job_basic_structure(job_manifest):
    assert job_manifest['apiVersion'] == 'batch/v1'
    assert job_manifest['kind'] == 'Job'
    assert job_manifest['metadata']['name'] == 'bionemo-training'
    assert job_manifest['metadata']['namespace'] == 'bionemo-training'

def test_container_resources(job_manifest):
    container = job_manifest['spec']['template']['spec']['containers'][0]
    assert container['resources']['limits']['nvidia.com/gpu'] == 1

def test_volume_mounts(job_manifest):
    container = job_manifest['spec']['template']['spec']['containers'][0]
    volume_mounts = {mount['name']: mount for mount in container['volumeMounts']}
    
    # Check bionemo-storage mounts
    assert 'bionemo-storage' in volume_mounts
    training_mount = next(
        mount for mount in container['volumeMounts']
        if mount['mountPath'] == '/mnt/data'
    )
    logs_mount = next(
        mount for mount in container['volumeMounts']
        if mount['mountPath'] == '/workspace/bionemo2/results'
    )
    
    assert training_mount['subPath'] == 'training-data'
    assert logs_mount['subPath'] == 'tensorboard-logs'
    
    # Check other required mounts
    assert 'config-volume' in volume_mounts
    assert 'script-volume' in volume_mounts

def test_volumes_configuration(job_manifest):
    volumes = {vol['name']: vol for vol in job_manifest['spec']['template']['spec']['volumes']}
    
    assert 'bionemo-storage' in volumes
    assert volumes['bionemo-storage']['persistentVolumeClaim']['claimName'] == 'bionemo-filestore'