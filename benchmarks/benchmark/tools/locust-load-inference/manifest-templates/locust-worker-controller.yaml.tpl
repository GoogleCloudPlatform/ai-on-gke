apiVersion: "apps/v1"
kind: "Deployment"
metadata:
  name: locust-worker
  namespace: ${namespace}
  labels:
    name: locust-worker
spec:
  replicas: ${num_locust_workers}
  selector:
    matchLabels:
      app: locust-worker
  template:
    metadata:
      labels:
        app: locust-worker
        examples.ai.gke.io/source: ai-on-gke-benchmarks
    spec:
      serviceAccountName: ${ksa}
      containers:
        - name: locust-worker
          image: ${artifact_registry}/locust-tasks:latest
          env:
            - name: LOCUST_MODE
              value: worker
            - name: REQUEST_TYPE
              value: ${request_type}
            - name: LOCUST_MASTER
              value: locust-master
            - name: TARGET_HOST
              value: ${inference_server_service}
            - name: BACKEND
              value: ${inference_server_framework}
            - name: BEST_OF
              value: ${best_of}
            - name: GCS_PATH
              value: ${gcs_path}
            - name: MAX_NUM_PROMPTS
              value: ${max_num_prompts}
            - name: MAX_OUTPUT_LEN
              value: ${max_output_len}
            - name: MAX_PROMPT_LEN
              value: ${max_prompt_len}
            - name: SAX_MODEL
              value: ${sax_model}
            - name: TOKENIZER
              value: ${tokenizer}
            - name: USE_BEAM_SEARCH
              value: ${use_beam_search}
%{ for hugging_face_token_secret in hugging_face_token_secret_list ~}
            - name: HUGGINGFACE_TOKEN
              valueFrom:
                secretKeyRef:
                  name: hf-key
                  key: HF_TOKEN
%{ endfor ~}
%{ for hf_token in k8s_hf_secret_list ~}
            - name: HUGGINGFACE_TOKEN
              valueFrom:
                secretKeyRef:
                  name: hf-token
                  key: HF_TOKEN
%{ endfor ~}