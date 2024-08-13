apiVersion: v1
kind: Secret
metadata:
  name: hf-token
  namespace: ${namespace}
data:
  HF_TOKEN: ${hugging_face_token_b64}