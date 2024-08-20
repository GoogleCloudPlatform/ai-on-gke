apiVersion: batch/v1
kind: Job
metadata:
  name: lpg-${combo}
  namespace: ${namespace}
  labels:
    name: latency-profile-generator
spec:
  template:
    spec:
      serviceAccountName: ${latency_profile_kubernetes_service_account}
      restartPolicy: Never
      containers:
        - name: latency-profile-generator
          image: ${artifact_registry}/latency-profile:latest
          resources:
            limits:
              nvidia.com/gpu: 1
          command: ["bash", "-c", "./latency_throughput_curve.sh"]
          env:
            - name: TOKENIZER
              value: ${tokenizer}
            - name: IP
              value: ${inference_server_service}
            - name: PORT
              value: ${inference_server_service_port}
            - name: BACKEND
              value: ${inference_server_framework}
            - name: INPUT_LENGTH
              value: ${max_prompt_len}
            - name: OUTPUT_LENGTH
              value: ${max_output_len}
            - name: REQUEST_RATES
              value: ${request_rates}
            - name: OUTPUT_BUCKET
              value: ${output_bucket}
%{ for hugging_face_token_secret in hugging_face_token_secret_list ~}
            - name: HF_TOKEN
              valueFrom:
                secretKeyRef:
                  name: hf-token
                  key: HF_TOKEN
%{ endfor ~}
%{ for hf_token in k8s_hf_secret_list ~}
            - name: HF_TOKEN
              valueFrom:
                secretKeyRef:
                  name: hf-token
                  key: HF_TOKEN
%{ endfor ~}
      nodeSelector:
        cloud.google.com/gke-accelerator: nvidia-l4   # nvidia-h100-80gb, nvidia-l4
        iam.gke.io/gke-metadata-server-enabled: "true"