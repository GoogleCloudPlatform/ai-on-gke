apiVersion: apps/v1
kind: Deployment
metadata:
  name: lexitrail-ui-deployment
  annotations:
    terraform.io/change-cause: "${ui_files_hash}"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: lexitrail-ui
  template:
    metadata:
      labels:
        app: lexitrail-ui
      annotations:
        redeploy-hash: "${ui_files_hash}"
    spec:
      containers:
      - name: lexitrail-ui
        image: ${region}-docker.pkg.dev/${project_id}/${repo_name}/${container_name}:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 3000
