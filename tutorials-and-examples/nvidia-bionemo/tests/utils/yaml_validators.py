# tests/utils/yaml_validators.py
import yaml
from typing import Dict, Any, List
from kubernetes import client
from kubernetes.client.rest import ApiException

class YAMLValidationError(Exception):
    """Custom exception for YAML validation errors"""
    pass

def validate_yaml_syntax(content: str) -> bool:
    """
    Validates basic YAML syntax
    
    Args:
        content: YAML content as string
    
    Returns:
        bool: True if valid, raises YAMLValidationError if invalid
    """
    try:
        yaml.safe_load(content)
        return True
    except yaml.YAMLError as e:
        raise YAMLValidationError(f"Invalid YAML syntax: {str(e)}")

def validate_k8s_resource_requirements(container: Dict[str, Any]) -> bool:
    """
    Validates Kubernetes container resource requirements
    
    Args:
        container: Container spec dictionary
    
    Returns:
        bool: True if valid, raises YAMLValidationError if invalid
    """
    if 'resources' not in container:
        raise YAMLValidationError("Container must specify resource requirements")
    
    resources = container['resources']
    if 'limits' not in resources or 'requests' not in resources:
        raise YAMLValidationError("Container must specify both resource limits and requests")
    
    return True

def validate_volume_mounts(container: Dict[str, Any], volumes: List[Dict[str, Any]]) -> bool:
    """
    Validates that all volume mounts in a container have corresponding volumes
    
    Args:
        container: Container spec dictionary
        volumes: List of volume specifications
    
    Returns:
        bool: True if valid, raises YAMLValidationError if invalid
    """
    if 'volumeMounts' not in container:
        return True
    
    volume_names = {vol['name'] for vol in volumes}
    mount_names = {mount['name'] for mount in container['volumeMounts']}
    
    missing_volumes = mount_names - volume_names
    if missing_volumes:
        raise YAMLValidationError(
            f"Volume mounts reference non-existent volumes: {missing_volumes}"
        )
    
    return True

def validate_configmap_data(configmap: Dict[str, Any]) -> bool:
    """
    Validates ConfigMap data structure
    
    Args:
        configmap: ConfigMap manifest dictionary
    
    Returns:
        bool: True if valid, raises YAMLValidationError if invalid
    """
    if 'data' not in configmap:
        raise YAMLValidationError("ConfigMap must contain 'data' field")
    
    if not isinstance(configmap['data'], dict):
        raise YAMLValidationError("ConfigMap 'data' must be a key-value mapping")
    
    return True

def validate_pvc_spec(pvc: Dict[str, Any]) -> bool:
    """
    Validates PersistentVolumeClaim specification
    
    Args:
        pvc: PVC manifest dictionary
    
    Returns:
        bool: True if valid, raises YAMLValidationError if invalid
    """
    required_fields = ['accessModes', 'resources']
    for field in required_fields:
        if field not in pvc['spec']:
            raise YAMLValidationError(f"PVC spec must contain '{field}'")
    
    if 'requests' not in pvc['spec']['resources']:
        raise YAMLValidationError("PVC resources must specify 'requests'")
    
    if 'storage' not in pvc['spec']['resources']['requests']:
        raise YAMLValidationError("PVC must specify storage request")
    
    return True

def validate_metadata(resource: Dict[str, Any], required_labels: List[str] = None) -> bool:
    """
    Validates Kubernetes resource metadata
    
    Args:
        resource: Kubernetes resource dictionary
        required_labels: List of required label keys
    
    Returns:
        bool: True if valid, raises YAMLValidationError if invalid
    """
    if 'metadata' not in resource:
        raise YAMLValidationError("Resource must contain metadata")
    
    metadata = resource['metadata']
    if 'name' not in metadata:
        raise YAMLValidationError("Resource must have a name")
    
    if required_labels:
        if 'labels' not in metadata:
            raise YAMLValidationError("Resource must have labels")
        
        missing_labels = set(required_labels) - set(metadata['labels'].keys())
        if missing_labels:
            raise YAMLValidationError(f"Missing required labels: {missing_labels}")
    
    return True

def validate_k8s_api_version(resource: Dict[str, Any]) -> bool:
    """
    Validates that the API version is valid for the resource kind
    
    Args:
        resource: Kubernetes resource dictionary
    
    Returns:
        bool: True if valid, raises YAMLValidationError if invalid
    """
    required_fields = ['apiVersion', 'kind']
    for field in required_fields:
        if field not in resource:
            raise YAMLValidationError(f"Resource must specify '{field}'")
    
    try:
        client.ApiClient().sanitize_for_serialization(resource)
        return True
    except ApiException as e:
        raise YAMLValidationError(f"Invalid resource definition: {str(e)}")