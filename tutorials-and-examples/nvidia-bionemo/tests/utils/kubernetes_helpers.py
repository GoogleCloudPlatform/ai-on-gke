import yaml
from kubernetes import client, config
from kubernetes.client.rest import ApiException

def load_yaml_manifest(file_path):
    with open(file_path, 'r') as f:
        documents = list(yaml.safe_load_all(f))
        return documents[0] if len(documents) == 1 else documents

def validate_k8s_object(manifest):
    try:
        client.ApiClient().sanitize_for_serialization(manifest)
        return True
    except ApiException as e:
        return False