apiVersion: v1
kind: Service
metadata:
  labels:
    name: lexitrail-match-making-mmf
  name: lexitrail-match-making-mmf
spec:
  selector:
    app: lexitrail-match-making-mmf
  ports:
    - protocol: TCP
      port: 50502
  type: ClusterIP