"""Problem verifiers that use log-based data sources."""

import logging
from google.cloud import logging as cloud_logging
from .runner import ProblemDetectorInput, VerificationResult, DetectorResult

logger = logging.getLogger(__name__)

def check_step_time_reported(detector_input: ProblemDetectorInput, detector_result: DetectorResult) -> VerificationResult:
    """Verifies that system metrics are being reported.
    
    This verifier checks if step time metrics are being reported for the jobset
    identified in the detector result.
    """
    # Extract jobset information from the detector result
    jobset_name = detector_result.jobset_name
    if not jobset_name:
        return VerificationResult(
            abort=True,
            reason="Cannot verify step time reporting: jobset_name not provided in detector result"
        )
    
    # Create a client using the project ID from the detector input
    client = cloud_logging.Client(project=detector_input.project_id)

    # Build the filter string using information from the detector input
    filter_str = (
        f'resource.labels.cluster_name="{detector_input.cluster_name}" '
        f'resource.labels.namespace_name="{detector_input.namespace}" '
        f'resource.type="k8s_container" '
        f'jsonPayload.message:"Average step time:" '
        f'labels."k8s-pod/jobset_sigs_k8s_io/jobset-name"="{jobset_name}" '
        f'timestamp >= "{detector_input.start_time.isoformat()}" '
        f'timestamp <= "{detector_input.end_time.isoformat()}"'
    )

    logger.debug(f"Applying log filter: {filter_str}")

    # Query the logs
    iterator = client.list_entries(
        filter_=filter_str,
        page_size=1,  # Only need one occurrence to verify metrics
        order_by=cloud_logging.DESCENDING
    )

    # Check for any matching data
    sample = None
    for entry in iterator:
        message = entry.payload
        if isinstance(message, dict):
            message = message.get('message', str(message))
        sample = str(message)
        break  # Only need one sample

    if sample:
        return VerificationResult(
            abort=True,
            reason=f"Found step time report: {sample}"
        )

    return VerificationResult(
        abort=False,
        reason=f"No step time report found for jobset {jobset_name} in namespace {detector_input.namespace} within {detector_input.cluster_name}."
    )

__all__ = [
    'check_step_time_reported',
] 