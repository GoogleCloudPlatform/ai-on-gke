apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    name: lexitrail-match-making-director
  name: lexitrail-match-making-director
spec:
  replicas: 1
  selector:
    matchLabels:
      app: lexitrail-match-making-director
  template:
    metadata:
      labels:
        app: lexitrail-match-making-director
    spec:
      serviceAccountName: fleet-allocator
      containers:
        - name: lexitrail-match-making-director
          image: ${region}-docker.pkg.dev/${project_id}/${repo_name}/${container_name}:latest
          imagePullPolicy: Always