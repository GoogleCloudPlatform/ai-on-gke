apiVersion: v1
kind: Service
metadata:
  labels:
    name: lexitrail-match-making-frontend
  name: lexitrail-match-making-frontend
spec:
  selector:
    app: lexitrail-match-making-frontend
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8001
      # Should limit the access to ClusterIP in production
  type: LoadBalancer

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  labels:
    name: lexitrail-match-making-frontend
  name: lexitrail-match-making-frontend
spec:
  defaultBackend:
    service:
      name: lexitrail-match-making-frontend
      port:
        number: 8001