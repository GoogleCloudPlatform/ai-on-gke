apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: ${sql_namespace}
spec:
  selector:
    matchLabels:
      app: mysql
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - image: mysql:8.0
        name: mysql
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "${db_root_password}"
        ports:
        - containerPort: 3306
          name: mysql
        args:  # Add this to pass arguments to the MySQL server
        - "--local-infile=1"  # Enable local_infile on the server side
        volumeMounts:
        - name: mysql-persistent-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-persistent-storage
        persistentVolumeClaim:
          claimName: mysql-pvc
