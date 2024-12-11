apiVersion: apps/v1
kind: Deployment
metadata:
  name: lexitrail-backend
  namespace: ${backend_namespace}
  annotations:
    terraform.io/change-cause: "${backend_files_hash}"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: lexitrail-backend
  template:
    metadata:
      labels:
        app: lexitrail-backend
      annotations:
        redeploy-hash: "${backend_files_hash}"
    spec:
      serviceAccountName: default
      containers:
      - name: lexitrail-backend
        image: ${region}-docker.pkg.dev/${project_id}/${repo_name}/${container_name}:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 80
        env:
        - name: PORT
          value: "80"
        - name: MYSQL_FILES_BUCKET
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: MYSQL_FILES_BUCKET
        - name: SQL_NAMESPACE
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: SQL_NAMESPACE
        - name: DATABASE_NAME
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: DATABASE_NAME
        - name: GOOGLE_CLIENT_ID
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: GOOGLE_CLIENT_ID
        - name: PROJECT_ID
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: PROJECT_ID
        - name: LOCATION
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: LOCATION
        - name: DB_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: backend-secret
              key: DB_ROOT_PASSWORD