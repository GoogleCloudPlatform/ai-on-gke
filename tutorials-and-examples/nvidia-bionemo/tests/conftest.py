import pytest
import os
from kubernetes import config

@pytest.fixture(scope="session")
def kube_config():
    if os.getenv('KUBECONFIG'):
        config.load_kube_config()
    else:
        config.load_incluster_config()