# Problem Detection Framework

This package provides a framework for detecting system problems. While the current implementation uses Google Cloud logs, the framework is designed to support flexible problem detection methods.

## Description

The framework implements a two-phase problem detection strategy:

The runner executes each VerifiedDetector in sequence:

1. Run the detector to check for problems
2. If a problem is found, run all verifiers for that detector
3. If all verifiers fail, take the action from the detector
    
The action that is returned is the action from the first detector that finds a problem
and passes all its verifiers.

### Configuration

Configure the system verification using the following environment variables:

- `CLUSTER_NAME`: GKE cluster name (will be determined from metadata server if not present)
- `PROJECT_ID`: Project (will be determined from metadata server if not present)
- `NAMESPACE`: Kubernetes namespace to filter detection to (defaults to `default` if not set)
- Data Collection Window (one of the following):
  - `START_TIME` and `END_TIME`: Explicit window in ISO format (e.g., "2025-03-13T17:00:00-04:00")
  - `TIME_WINDOW_MINUTES`: Duration in minutes to look back from current time (e.g., "60" for last hour)
  - If neither is set, defaults to a 10-minute window
- `MAX_SAMPLES`: Maximum number of data points to collect for each issue (default: 3)
- `LOG_LEVEL`: Set logging level (defaults to "INFO"). Use "DEBUG" to see detailed information
  - `INFO`: Shows basic operational information (default)
  - `DEBUG`: Shows detailed debugging information
  - `WARNING`: Shows only warning and error messages
  - `ERROR`: Shows only error messages
- `CONTROLLER_URL`: URL of the controller service for submitting action requests when problems are detected


## Build

```bash
export DETECTOR_IMAGE=us-docker.pkg.dev/${PROJECT_ID}/default/autometric-failover-detector:$(git rev-parse --short HEAD)
podman build --platform linux/amd64 -t $DETECTOR_IMAGE .
podman push $DETECTOR_IMAGE
```

## Deploy

The detector can be deployed as a CronJob in Kubernetes. The configuration files are located in the `config/` directory and use Kustomize for configuration management.

Create a GCP service account and set up workload identity.

```bash
export PROJECT_ID=$(gcloud config get project)

# Create the GCP service account
gcloud iam service-accounts create autometric-failover-detector \
    --project=${PROJECT_ID}

# Grant necessary permissions
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:autometric-failover-detector@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/logging.viewer"

# Allow workload identity binding
gcloud iam service-accounts add-iam-policy-binding \
    autometric-failover-detector@${PROJECT_ID}.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${PROJECT_ID}.svc.id.goog[autometric-failover-system/detector]"
```

Apply the Kubernetes configurations using Kustomize.

```bash
kubectl apply --server-side -k config/${PROJECT_ID}
```

### Example Usage

Setup:

```bash
uv venv

# Activate the virtual environment
source .venv/bin/activate

# Install dependencies
uv pip install -e .
```

Run the controller (`../controller/`) in no-op mode:

```bash
go run ./cmd/main.go --no-op-action-taker
```

Run the problem detectors:

```bash
export CONTROLLER_URL=http://localhost:8080
export PROJECT_ID="my-project-id"
export CLUSTER_NAME="my-cluster-name"     
export START_TIME="2025-04-04T11:00:00-07:00"
export END_TIME="2025-04-04T11:15:00-07:00"
export LOG_LEVEL=DEBUG
python -m detector.main
```