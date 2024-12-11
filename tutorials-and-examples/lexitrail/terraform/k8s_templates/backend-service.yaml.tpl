apiVersion: v1
kind: Service
metadata:
  name: lexitrail-backend-service
  namespace: ${backend_namespace}
spec:
  selector:
    app: lexitrail-backend
  ports:
    - protocol: TCP
      port: 80  # Expose service on port 80
      targetPort: 80  # Target container's port 80
  type: LoadBalancer  # Expose service externally
