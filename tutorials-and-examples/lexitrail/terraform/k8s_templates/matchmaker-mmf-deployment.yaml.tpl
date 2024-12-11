apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    name: lexitrail-match-making-mmf
  name: lexitrail-match-making-mmf
spec:
  replicas: 1
  selector:
    matchLabels:
      app: lexitrail-match-making-mmf
  template:
    metadata:
      labels:
        app: lexitrail-match-making-mmf
    spec:
      containers:
        - name: lexitrail-match-making-mmf
          image:  ${region}-docker.pkg.dev/${project_id}/${repo_name}/${container_name}:latest
          imagePullPolicy: Always
          ports:
            - containerPort: 50502