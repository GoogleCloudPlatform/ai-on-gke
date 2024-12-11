apiVersion: "autoscaling.agones.dev/v1"
kind: FleetAutoscaler
metadata:
  name: fleet-autoscaler-middle-layer-app
spec:
  fleetName: middle-layer-app
  policy:
    type: Buffer
    buffer:
      bufferSize: 5
      minReplicas: 10
      maxReplicas: 15