apiVersion: agones.dev/v1
kind: Fleet
metadata:
  name: middle-layer-app
spec:
  replicas: 10
  template:
    spec:
      health:
        initialDelaySeconds: 20
        periodSeconds: 10
      ports:
        - name: default
          containerPort: 7101
          protocol: TCP
      template:
        spec:
          affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                - matchExpressions:
                  - key: game-server
                    operator: In
                    values:
                    - "true"
          tolerations:
          - key: "game-server"
            operator: Equal
            value: "true"
            effect: NoExecute
          containers:
            - name: middle-layer-app
              image: ${region}-docker.pkg.dev/${project_id}/${repo_name}/${container_name}:latest
              resources:
                requests:
                  memory: 256Mi
                  cpu: 80m
                limits:
                  memory: 256Mi
                  cpu: 80m
