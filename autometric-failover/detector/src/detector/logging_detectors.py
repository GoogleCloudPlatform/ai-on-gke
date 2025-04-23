"""Problem detectors that use log-based data sources."""

import re
import logging
from google.cloud import logging as cloud_logging
from .runner import ProblemDetectorInput, DetectorResult

logger = logging.getLogger(__name__)

def check_workers_didnt_report_error(detector_input: ProblemDetectorInput) -> DetectorResult:
    """Detects worker error conditions in logs."""
    client = cloud_logging.Client(project=detector_input.project_id)

    filter_str = (
        f'resource.labels.cluster_name="{detector_input.cluster_name}" '
        f'resource.labels.namespace_name="{detector_input.namespace}" '
        f'resource.type="k8s_container" '
        f'jsonPayload.message:"Some workers didn\'t report an error after 5 minutes" '
        f'timestamp >= "{detector_input.start_time.isoformat()}" '
        f'timestamp <= "{detector_input.end_time.isoformat()}"'
    )

    logger.debug(f"Applying log filter: {filter_str}")

    iterator = client.list_entries(
        filter_=filter_str,
        page_size=1,  # Only need one entry
        order_by=cloud_logging.DESCENDING
    )

    # Get the first entry if available
    entry = next(iterator, None)
    
    if not entry:
        return DetectorResult(
            problem=False,
            reason="No worker error logs found",
        )
    
    message = entry.payload
    if isinstance(message, dict):
        message = message.get('message', str(message))
    
    message_str = str(message)
    
    # Extract slice number from message
    slice_matches = re.findall(r'slice(\d+)-', message_str)
    first_slice = sorted(slice_matches)[0] if slice_matches else None
    
    # Extract jobset name from labels
    jobset_name = None
    if entry.labels:
        jobset_name = entry.labels.get('k8s-pod/jobset_sigs_k8s_io/jobset-name')
    
    return DetectorResult(
        problem=True,
        reason=f"Worker error detected: {message_str}",
        job_name=f"{jobset_name}-job-{first_slice}" if first_slice and jobset_name else jobset_name,
        jobset_name=jobset_name,
    )

def check_exec_error(detector_input: ProblemDetectorInput) -> DetectorResult:
    """Detects exec format errors in container logs."""
    client = cloud_logging.Client(project=detector_input.project_id)

    filter_str = (
        f'resource.labels.cluster_name="{detector_input.cluster_name}" '
        f'(resource.labels.namespace_name="kube-system" OR resource.labels.namespace_name="{detector_input.namespace}") '
        f'resource.type="k8s_container" '
        f'textPayload:"exec format error" '
        f'severity="ERROR" '
        f'timestamp >= "{detector_input.start_time.isoformat()}" '
        f'timestamp <= "{detector_input.end_time.isoformat()}"'
    )

    logger.debug(f"Applying log filter: {filter_str}")

    iterator = client.list_entries(
        filter_=filter_str,
        page_size=1,  # We only need the first record
        order_by=cloud_logging.DESCENDING
    )

    # Get the first entry if available
    entry = next(iterator, None)
    
    if not entry:
        return DetectorResult(
            problem=False,
            reason="No exec format error logs found",
        )
    
    logger.debug(f"Entry: {entry}")

    return DetectorResult(
        problem=True,
        reason="Exec format error detected in container logs",
        node_name=entry.labels.get('compute.googleapis.com/resource_name')
    )

__all__ = [
    'check_workers_didnt_report_error',
    'check_exec_error',
]
