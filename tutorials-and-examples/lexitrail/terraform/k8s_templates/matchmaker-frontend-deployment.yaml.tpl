apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    name: lexitrail-match-making-frontend
  name: lexitrail-match-making-frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: lexitrail-match-making-frontend
  template:
    metadata:
      labels:
        app: lexitrail-match-making-frontend
    spec:
      containers:
        - name: lexitrail-match-making-frontend
          image: ${region}-docker.pkg.dev/${project_id}/${repo_name}/${container_name}:latest
          imagePullPolicy: Always
          ports:
            - containerPort: 8001
          command: ["/app/frontend"]