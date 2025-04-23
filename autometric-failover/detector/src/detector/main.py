import json
import os
import sys
import logging
import urllib.request
from datetime import datetime, timedelta, timezone
from typing import List, Optional
from .runner import (
    ProblemDetectorInput, 
    VerifiedDetector, 
    ProblemDetectorRunner,
    ActionType
)
#from .logging_verifiers import check_step_time_reported
from .logging_detectors import check_exec_error #, check_workers_didnt_report_error
from .client import ControllerClient, ActionType

# Configure root logger
log_level = os.getenv('LOG_LEVEL', 'INFO').upper()
    
logging.basicConfig(
    level=getattr(logging, log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def get_metadata_attribute(key: str) -> Optional[str]:
    """Get a metadata attribute from GCP metadata server.
    
    Args:
        key: The metadata key to retrieve
        
    Returns:
        Optional[str]: The attribute value or None if not found
    """
    try:
        url = f"http://metadata.google.internal/computeMetadata/v1/{key}"
        req = urllib.request.Request(url)
        req.add_header("Metadata-Flavor", "Google")
        with urllib.request.urlopen(req, timeout=1) as response:
            return response.read().decode('utf-8')
    except Exception as e:
        logger.debug(f"Failed to get metadata attribute '{key}': {e}")
        return None

def get_project_id() -> Optional[str]:
    """Get project ID from GCP metadata server."""
    try:
        return get_metadata_attribute("project/project-id")
    except Exception as e:
        logger.debug(f"Failed to get project ID from metadata server: {e}")
        return None

def get_cluster_name() -> Optional[str]:
    """Get GKE cluster name from GCP metadata server."""
    try:
        return get_metadata_attribute("instance/attributes/cluster-name")
    except Exception as e:
        logger.debug(f"Failed to get cluster name from metadata server: {e}")
        return None

def get_required_env_or_metadata(name: str, metadata_fn) -> str:
    """Get value from environment variable or metadata server.
    
    Args:
        name: Name of the environment variable
        metadata_fn: Function to call to get value from metadata server
        
    Returns:
        str: Value from environment variable or metadata server
    """
    value = os.getenv(name)
    if not value:
        logger.debug(f"Environment variable {name} not set, trying metadata server")
        value = metadata_fn()
        if not value:
            logger.error(f"Could not get {name} from environment or metadata server")
            sys.exit(1)
        logger.info(f"Got {name}={value} from metadata server")
    return value

def main():
    # Get required values from environment or metadata server
    cluster_name = get_required_env_or_metadata("CLUSTER_NAME", get_cluster_name)
    project_id = get_required_env_or_metadata("PROJECT_ID", get_project_id)
    
    # Get optional environment variables
    namespace = os.getenv("NAMESPACE", "default")
    controller_url = os.getenv("CONTROLLER_URL")
    dry_run = os.getenv("DRY_RUN", "true").lower() != "false"
    logger.debug(f"Using namespace: {namespace}")
    logger.debug(f"Dry run mode: {dry_run}")
    
    # Configure time window for analysis
    end_time = datetime.now(timezone.utc)
    start_time_str = os.getenv("START_TIME")
    end_time_str = os.getenv("END_TIME")
    time_window_minutes_str = os.getenv("TIME_WINDOW_MINUTES")
    
    if start_time_str and end_time_str:
        start_time = datetime.fromisoformat(start_time_str).astimezone(timezone.utc)
        end_time = datetime.fromisoformat(end_time_str).astimezone(timezone.utc)
        logger.info(f"Using specified time window: {start_time} to {end_time}")
    elif time_window_minutes_str:
        try:
            minutes = int(time_window_minutes_str)
            start_time = end_time - timedelta(minutes=minutes)
            logger.info(f"Using {minutes}-minute time window: {start_time} to {end_time}")
        except ValueError:
            logger.error(f"Invalid TIME_WINDOW_MINUTES value '{time_window_minutes_str}'. Must be an integer number of minutes.")
            sys.exit(1)
    else:
        start_time = end_time - timedelta(minutes=10)
        logger.info(f"Using default 10-minute time window: {start_time} to {end_time}")
    
    # Initialize detector with input parameters
    detector_input = ProblemDetectorInput(
        cluster_name=cluster_name,
        project_id=project_id,
        namespace=namespace,
        start_time=start_time,
        end_time=end_time
    )
    
    logger.info("Starting problem detection")
    
    # Configure and run detectors
    detector_runner = ProblemDetectorRunner(
        verified_detectors=[
            VerifiedDetector(
                detector=check_exec_error,
                verifiers=[],
                action_type=ActionType.REPAIR_NODEPOOL
            )
            # TODO: Once we support job->node_pool resolution in the controller,
            # we can add the following detector:
            #VerifiedDetector(
            #    detector=check_workers_didnt_report_error,
            #    verifiers=[check_step_time_reported],
            #    action_type=ActionType.CORDON_AND_REPAIR_NODEPOOL
            #)
        ]
    )
    action_request = detector_runner.run(detector_input)
    
    # Submit action request if problems detected
    if action_request is not None and controller_url:
        try:
            # Set dry_run parameter based on environment variable
            action_request.dry_run = dry_run
            logger.info(f"Setting dry_run={dry_run} on action request")

            # Output detection results as JSON
            json.dump(action_request.to_dict(), sys.stdout, indent=2)
            sys.stdout.write('\n')
            
            client = ControllerClient(controller_url)
            response = client.submit_action(action_request)
            if response.error:
                logger.error(f"Controller action failed: {response.error}")
            else:
                logger.info(f"Successfully submitted action request with ID: {response.id}")
                
        except Exception as e:
            logger.error(f"Failed to submit action request to controller: {e}")

if __name__ == "__main__":
    main()