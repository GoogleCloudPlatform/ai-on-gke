"""Problem detector runner and type definitions."""

import logging
from dataclasses import dataclass
from datetime import datetime
from typing import Callable, List, Optional
from dataclasses_json import dataclass_json
from .client import ActionRequest, ActionType, PreflightChecks

logger = logging.getLogger(__name__)

@dataclass
class ProblemDetectorInput:
    """Input parameters for system verification and issue detection.
    """
    cluster_name: str
    project_id: str
    namespace: str
    start_time: datetime
    end_time: datetime

@dataclass_json
@dataclass
class VerificationResult:
    """Result from a system verification check.
    
    Attributes:
        abort: True if verification indicates the action should be aborted, False if action should proceed
        reason: Human-readable description of system state
    """
    abort: bool
    reason: str

@dataclass_json
@dataclass
class DetectorResult:
    """Result from a problem detection check.
    
    Attributes:
        problem: True if issue found, False if no issues
        reason: Description of detected issue
        job_name: Affected job name (optional)
        jobset_name: Affected jobset name (optional)
        node_pool: Affected node pool (optional)
        node_name: Affected node name (optional)
    """
    problem: bool
    reason: str
    job_name: Optional[str] = None
    jobset_name: Optional[str] = None
    node_pool: Optional[str] = None
    node_name: Optional[str] = None

# Type aliases for detector functions
Verifier = Callable[[ProblemDetectorInput, DetectorResult], VerificationResult]
"""Function type for verifying basic system operation.

Verifiers are used to confirm basic system operation before taking action.
All verifiers must return abort=False to proceed with the action.
"""

Detector = Callable[[ProblemDetectorInput], DetectorResult]
"""Function type for detecting specific problems in a system.

Detectors are used to identify specific problems.
"""

@dataclass
class VerifiedDetector:
    """A detector with associated verifiers that must all fail for the action to be taken.
    
    Attributes:
        detector: The detector function that identifies problems
        verifiers: List of verifier functions that must all fail for the action to be taken
        action_type: The type of action to take when all verifiers fail
    """
    detector: Detector
    verifiers: List[Verifier]
    action_type: ActionType

@dataclass
class ProblemDetectorRunner:
    """Runner for executing problem detectors with their associated verifiers.
    
    The runner executes each VerifiedDetector in sequence:
    1. Run the detector to check for problems
    2. If a problem is found, run all verifiers for that detector
    3. If all verifiers fail, take the action from the detector
    
    The action that is returned is the action from the first detector that finds a problem
    and passes all its verifiers.
    
    Attributes:
        verified_detectors: List of VerifiedDetector objects to run
    """
    verified_detectors: List[VerifiedDetector]
    
    def run(self, detector_input: ProblemDetectorInput) -> Optional[ActionRequest]:
        """Run all configured detectors and their verifiers in order.
        
        Args:
            detector_input: ProblemDetectorInput object containing system parameters
            
        Returns:
            Optional[ActionRequest] - The action to take if a problem is found and verified,
                                     None otherwise
        """
        action = None
        
        # Run each verified detector
        for verified_detector in self.verified_detectors:
            # Run the detector first
            detector_result = verified_detector.detector(detector_input)
            
            # If a problem is found, run the verifiers
            if detector_result.problem:
                logger.info(f"Problem detected: {detector_result.reason}")
                
                should_abort = False
                for verifier in verified_detector.verifiers:
                    result = verifier(detector_input, detector_result)
                    
                    if result.abort:
                        logger.info(f"Verification indicates the action should be aborted: {result.reason}")
                        should_abort = True
                        break
                
                # If all verifiers failed, take the action
                if not should_abort:
                    logger.info("No verifiers determined that the action should be aborted - returning action")
                    return ActionRequest(
                        requestor="problem_detector",
                        reason=detector_result.reason,
                        type=verified_detector.action_type,  # Use the action_type from VerifiedDetector
                        jobset_name=detector_result.jobset_name,
                        node_pool=detector_result.node_pool,
                        node_name=detector_result.node_name,
                    )
                else:
                    logger.info("Skipping action because a verifier indicated the action should be aborted")
        
        return None

__all__ = [
    'ProblemDetectorInput',
    'VerificationResult',
    'DetectorResult',
    'Verifier',
    'Detector',
    'VerifiedDetector',
    'ProblemDetectorRunner',
] 