import pytest
from utils.kubernetes_helpers import load_yaml_manifest

@pytest.fixture
def storage_class_manifest():
    return load_yaml_manifest('base/storage/storage-class.yaml')

@pytest.fixture
def pvc_manifest():
    return load_yaml_manifest('base/storage/pvcs.yaml')

def test_filestore_storage_class(storage_class_manifest):
    filestore = storage_class_manifest
    
    assert filestore['provisioner'] == 'filestore.csi.storage.gke.io'
    assert filestore['parameters']['tier'] == 'BASIC_HDD'
    assert filestore['volumeBindingMode'] == 'Immediate'
    assert filestore['allowVolumeExpansion'] is True

def test_bionemo_pvc(pvc_manifest):
    pvc = pvc_manifest
    
    assert pvc['metadata']['namespace'] == 'bionemo-training'
    assert pvc['spec']['accessModes'] == ['ReadWriteMany']
    assert pvc['spec']['storageClassName'] == 'filestore-storage'
    assert pvc['spec']['resources']['requests']['storage'] == '1Ti'