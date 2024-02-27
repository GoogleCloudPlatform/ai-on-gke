kind: Service
apiVersion: v1
metadata:
  name: locust-master
  namespace: ${namespace}
  labels:
    app: locust-master
spec:
  ports:
    - port: 5557
      targetPort: loc-master-p1
      protocol: TCP
      name: loc-master-p1
    - port: 5558
      targetPort: loc-master-p2
      protocol: TCP
      name: loc-master-p2
    - port: 8089
      targetPort: loc-master-web
      protocol: TCP
      name: loc-master-web
    - port: 8080
      target-port: metrics-port
      name: metrics-port
  selector:
    app: locust-master
---
kind: Service
apiVersion: v1
metadata:
  name: locust-master-web
  namespace: ${namespace}
  annotations:
    networking.gke.io/load-balancer-type: "External"
  labels:
    app: locust-master
spec:
  ports:
    - port: 8089
      targetPort: loc-master-web
      protocol: TCP
      name: loc-master-web
  selector:
    app: locust-master
  type: LoadBalancer