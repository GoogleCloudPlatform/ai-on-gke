apiVersion: "apps/v1"
kind: "Deployment"
metadata:
  name: locust-master
  namespace: ${namespace}
  labels:
    name: locust-master
spec:
  replicas: 1
  selector:
    matchLabels:
      app: locust-master
  template:
    metadata:
      labels:
        app: locust-master
    spec:
      serviceAccountName: ${ksa}
      containers:
        - name: locust-master
          image: ${artifact_registry}/locust-tasks:latest
          env:
            - name: LOCUST_MODE
              value: master
            - name: TARGET_HOST
              value: http://${inference_server_service}
            - name: BACKEND
              value: ${inference_server_framework}
            - name: ENABLE_CUSTOM_METRICS
              value: ${enable_custom_metrics}
          ports:
            - name: loc-master-web
              containerPort: 8089
              protocol: TCP
            - name: loc-master-p1
              containerPort: 5557
              protocol: TCP
            - name: loc-master-p2
              containerPort: 5558
              protocol: TCP
        - name: locust-custom-metrics-exporter
          image: ${artifact_registry}/locust-custom-exporter:latest
          ports:
            - name: cmetrics-port
              containerPort: 8080
              protocol: TCP
        - name: locust-metrics-exporter
          image: containersol/locust_exporter
          ports:
            - name: metrics-port
              containerPort: 9646
              protocol: TCP