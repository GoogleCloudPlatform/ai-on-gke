apiVersion: v1
kind: Service
metadata:
  name: mysql
  namespace: ${sql_namespace}
spec:
  ports:
    - port: 3306
  selector:
    app: mysql
  clusterIP: None
