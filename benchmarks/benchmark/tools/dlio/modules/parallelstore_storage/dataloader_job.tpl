apiVersion: batch/v1
kind: Job
metadata:
  name: data-loader-job
  namespace: ${namespace}
spec:
  backoffLimit: 0
  template:
    metadata:
      name: data-loader-job
      annotations:
        gke-parallelstore/volumes: "true"
        gke-parallelstore/cpu-limit: "10"
        gke-parallelstore/memory-limit: 20Gi
    spec:
      restartPolicy: Never
      containers:
      - name: data-loader
        image: google/cloud-sdk:latest
        env:
          - name: BUCKET_NAME
            value: ${gcs_bucket}
        command:
          - "/bin/sh"
          - "-c"
          - gsutil -m cp -R gs://$BUCKET_NAME/* /disk/;
        resources:
          limits:
            cpu: "10"
            memory: 20Gi
          requests:
            cpu: "10"
            memory: 20Gi
        volumeMounts:
        - name: ml-perf-volume
          mountPath: /disk
      serviceAccountName: ${service_account}
      volumes:
      - name: ml-perf-volume
        persistentVolumeClaim:
          claimName:  ${pvc_name}
