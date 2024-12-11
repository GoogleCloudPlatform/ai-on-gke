apiVersion: v1
kind: Service
metadata:
  name: lexitrail-ui-service
spec:
  selector:
    app: lexitrail-ui
  ports:
  - protocol: TCP
    port: 80
    targetPort: 3000
  type: LoadBalancer

