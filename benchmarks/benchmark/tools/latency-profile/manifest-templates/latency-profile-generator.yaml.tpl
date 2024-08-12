apiVersion: "apps/v1"
kind: "Deployment"
metadata:
  name: lantency-profile-generator
  namespace: ${namespace}
  labels:
    name: lantency-profile-generator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: lantency-profile-generator
  template:
    metadata:
      labels:
        app: lantency-profile-generator
        examples.ai.gke.io/source: ai-on-gke-benchmarks
    spec:
      serviceAccountName: ${latency_profile_kubernetes_service_account}
      containers:
        - name: lantency-profile-generator
          image: ${artifact_registry}/latency-profile:latest
          command: ["bash", "-c", "./latency_throughput_curve.sh"]
          env:
            - name: TOKENIZER
              value: ${tokenizer}
            - name: IP
              value: ${inference_server_service}
            - name: BACKEND
              value: ${inference_server_framework}
            - name: INPUT_LENGTH
              value: ${max_prompt_len}
            - name: OUTPUT_LENGTH
              value: ${max_output_len}
            - name: OUTPUT_BUCKET
              value: ${output_bucket}
%{ for hugging_face_token_secret in hugging_face_token_secret_list ~}
            - name: HF_TOKEN
              valueFrom:
                secretKeyRef:
                  name: hf-token
                  key: HF_TOKEN
%{ endfor ~}