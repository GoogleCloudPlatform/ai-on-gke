apiVersion: monitoring.googleapis.com/v1
kind: PodMonitoring
metadata:
  name: locust-scrapper
  namespace: ${namespace}
spec:
  selector:
    matchLabels:
      app: locust-master
  endpoints:
  - port: 8080
    interval: 5s