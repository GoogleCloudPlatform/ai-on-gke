import pytest
from utils.kubernetes_helpers import load_yaml_manifest

@pytest.fixture
def training_config():
    return load_yaml_manifest('fine-tuning/configmaps/training-config.yaml')

@pytest.fixture
def startup_script():
    return load_yaml_manifest('fine-tuning/configmaps/startup-script.yaml')

def test_training_params_content(training_config):
    params = training_config['data']['training-params']
    assert '--precision=bf16-mixed' in params
    assert '--num-gpus 1' in params
    assert '--micro-batch-size 2' in params
    assert '--num-steps 50' in params
    assert '--val-check-interval 10' in params
    assert '--encoder-frozen' in params
    assert '--lr 5e-3' in params
    assert '--lr-multiplier 1e2' in params
    assert '--scale-lr-layer regression_head' in params

def test_startup_script_permissions(startup_script):
    assert startup_script['metadata']['name'] == 'bionemo-finetuning-startup'
    assert 'start.sh' in startup_script['data']
    
def test_startup_script_content(startup_script):
    script_content = startup_script['data']['start.sh']
    assert 'nvidia-smi' in script_content
    assert 'finetuning.py' in script_content
    assert '/workspace/bionemo2/' in script_content