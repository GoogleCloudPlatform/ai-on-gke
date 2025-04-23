"""Client for sending action requests to the controller."""

import json
import logging
import uuid
from dataclasses import dataclass, field
from dataclasses_json import dataclass_json
from enum import Enum
from typing import Optional
import requests

logger = logging.getLogger(__name__)

class ActionType(str, Enum):
    """Available controller action types."""
    CORDON_NODEPOOL = "cordon_nodepool"
    CORDON_NODEPOOL_AND_RESTART_JOBSET = "cordon_nodepool_and_restart_jobset"
    CORDON_AND_REPAIR_NODEPOOL = "cordon_and_repair_nodepool"
    REPAIR_NODEPOOL = "repair_nodepool"

@dataclass_json
@dataclass
class PreflightChecks:
    """Pre-action validation checks.
    
    Attributes:
        expected_node_counts: If True, checks that expected number of nodes exist
            in the node pool based on TPU topology.
    """
    expected_node_counts: bool = False

@dataclass_json
@dataclass
class ActionRequest:
    """Request to take an action on a node pool or jobset.
    
    Attributes:
        id: Unique identifier for the action request. Will be generated if not provided.
        dry_run: If True, will just log and publish an event for the action, but not take any action.
        requestor: The user or system that requested the action. Required.
        reason: A human-readable reason for the action. Required.
        type: The type of action to perform. Required.
        namespace: The namespace that the action pertains to. Defaults to "default".
        jobset_name: The name of the Kubernetes JobSet that the action pertains to. Optional.
        node_pool: The name of the node pool to be acted upon. Optional.
        node_name: The name of the node to be acted upon. Optional.
        preflight_checks: A set of checks that will be performed to ensure that the action can be taken.
    """
    requestor: str
    reason: str
    type: ActionType
    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    dry_run: bool = False
    namespace: str = "default"
    jobset_name: Optional[str] = None
    node_pool: Optional[str] = None
    node_name: Optional[str] = None
    preflight_checks: PreflightChecks = field(default_factory=PreflightChecks)

@dataclass_json
@dataclass
class ActionResponse:
    """Response from controller after action request.
    
    Attributes:
        id: Unique identifier of the action request
        error: Error message if action failed
    """
    id: str
    error: Optional[str] = None

class ControllerClient:
    """Client for controller API communication."""
    
    def __init__(self, base_url: str):
        """Initialize with controller API base URL."""
        self.base_url = base_url.rstrip('/')
        
    def submit_action(self, request: ActionRequest) -> ActionResponse:
        """Submit action request to controller.
        
        Args:
            request: Action request to submit
            
        Returns:
            ActionResponse with request ID and error message if any
            
        Raises:
            requests.exceptions.RequestException: If request fails
        """
        url = f"{self.base_url}/actions"
        
        # Send request using dataclass_json serialization
        response = requests.post(url, json=request.to_dict())
        response.raise_for_status()
        
        # Parse response using dataclass_json
        return ActionResponse.from_dict(response.json()) 