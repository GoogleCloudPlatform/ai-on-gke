apiVersion: monitoring.googleapis.com/v1
kind: PodMonitoring
metadata:
  name: "lpg-driver-podmonitoring"
  namespace: ${namespace}
spec:
  selector:
    matchLabels:
      name: latency-profile-generator
  endpoints:
  - port: 9090
    interval: 15s
