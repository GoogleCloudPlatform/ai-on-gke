#!/bin/bash

# Define the namespace to watch
NAMESPACE=$1
TIMEOUT=$2
START_TIME=$(date +%s)

# Check if namespace is provided
if [[ -z "$NAMESPACE" ]]; then
  echo "Usage: $0 <namespace>"
  exit 1
fi

echo "Waiting for any pod to exist in the namespace '$NAMESPACE' (timeout: ${TIMEOUT}s)..."

# Loop until a pod exists in the namespace or timeout occurs
while true; do
  POD_COUNT=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)

  if [[ "$POD_COUNT" -gt 0 ]]; then
    echo "Pod(s) found in the namespace '$NAMESPACE'."
    break
  fi

  CURRENT_TIME=$(date +%s)
  ELAPSED_TIME=$((CURRENT_TIME - START_TIME))

  if [[ "$ELAPSED_TIME" -ge "$TIMEOUT" ]]; then
    echo "Timeout reached after ${TIMEOUT} seconds. No pods found in the namespace '$NAMESPACE'."
    exit 1
  fi

  echo "No pods found yet in the namespace '$NAMESPACE'. Checking again in 30 seconds..."
  sleep 30
done
