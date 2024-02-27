kind: Service
apiVersion: v1
metadata:
  name: locust-runner-api
  namespace: ${namespace}
  annotations:
    networking.gke.io/load-balancer-type: "External"
  labels:
    app: locust-runner
spec:
  ports:
    - port: 8000
      targetPort: 8000
      protocol: TCP
%{ for runner_endpoint_ip in runner_endpoint_ip_list ~}
  loadBalancerIP: ${runner_endpoint_ip}
%{ endfor ~}
  selector:
    app: locust-runner
  type: LoadBalancer
