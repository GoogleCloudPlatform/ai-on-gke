# tests/pretraining/test_configmaps.py
import pytest
from utils.kubernetes_helpers import load_yaml_manifest

@pytest.fixture
def training_config():
    return load_yaml_manifest('pretraining/configmaps/training-config.yaml')

@pytest.fixture
def startup_script():
    return load_yaml_manifest('pretraining/configmaps/startup-script.yaml')

def test_training_params_content(training_config):
    params = training_config['data']['training-params']
    assert '--precision=bf16-mixed' in params
    assert '--num-gpus 1' in params
    assert '--num-nodes 1' in params

def test_startup_script_permissions(startup_script):
    assert startup_script['metadata']['name'] == 'bionemo-startup-script'
    assert 'start.sh' in startup_script['data']