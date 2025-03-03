import pytest
from utils.kubernetes_helpers import load_yaml_manifest

@pytest.fixture
def tensorboard_deployment():
    return load_yaml_manifest('base/monitoring/tensorboard-deployment.yaml')

@pytest.fixture
def tensorboard_service():
    return load_yaml_manifest('base/monitoring/tensorboard-service.yaml')

def test_tensorboard_basic_structure(tensorboard_deployment):
    assert tensorboard_deployment['apiVersion'] == 'apps/v1'
    assert tensorboard_deployment['kind'] == 'Deployment'
    assert tensorboard_deployment['metadata']['name'] == 'tensorboard'
    assert tensorboard_deployment['metadata']['namespace'] == 'bionemo-training'

def test_tensorboard_deployment_spec(tensorboard_deployment):
    spec = tensorboard_deployment['spec']['template']['spec']
    assert spec['serviceAccountName'] == 'tensorboard-sa'
    
    container = spec['containers'][0]
    assert container['image'] == 'tensorflow/tensorflow:latest'
    assert container['command'] == ['tensorboard']
    assert '--port=6006' in container['args']
    assert container['volumeMounts'][0]['name'] == 'bionemo-storage'
    assert container['volumeMounts'][0]['mountPath'] == '/workspace/bionemo2/results'

def test_tensorboard_service_spec(tensorboard_service):
    spec = tensorboard_service['spec']
    assert spec['selector']['app'] == 'tensorboard'
    assert spec['ports'][0]['port'] == 6006
    assert spec['ports'][0]['targetPort'] == 6006
    assert spec['type'] == 'ClusterIP'