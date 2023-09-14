# Tutorial: Serving Llama 2 70b on GKE L4 GPUs
Create a GKE cluster:
```bash
gcloud container clusters create l4-demo --location ${REGION} \
  --workload-pool ${PROJECT_ID}.svc.id.goog \
  --enable-image-streaming --enable-shielded-nodes \
  --shielded-secure-boot --shielded-integrity-monitoring \
  --enable-ip-alias \
  --node-locations=$REGION-a \
  --workload-pool=${PROJECT_ID}.svc.id.goog \
  --addons GcsFuseCsiDriver   \
  --no-enable-master-authorized-networks \
  --machine-type n2d-standard-4 \
  --num-nodes 1 --min-nodes 1 --max-nodes 5 \
  --ephemeral-storage-local-ssd=count=2 \
  --enable-ip-alias \
  --enable-private-nodes  \
  --master-ipv4-cidr 172.16.0.32/28
```

Create a nodepool where each VM has 2 x L4 GPU:
```bash
gcloud container node-pools create g2-standard-24 --cluster l4-demo \
  --accelerator type=nvidia-l4,count=2,gpu-driver-version=latest \
  --machine-type g2-standard-24 \
  --ephemeral-storage-local-ssd=count=2 \
  --enable-autoscaling --enable-image-streaming \
  --num-nodes=0 --min-nodes=0 --max-nodes=3 \
  --shielded-secure-boot \
  --shielded-integrity-monitoring \
  --node-locations $REGION-a,$REGION-b --region $REGION --spot
```

Create a file named `text-generation-interface.yaml` with the following content:
[embedmd]:# (text-generation-interface.yaml)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llm
spec:
  replicas: 1
  selector:
    matchLabels:
      app: llm
  template:
    metadata:
      labels:
        app: llm
    spec:
      containers:
      - name: llm
        image: ghcr.io/huggingface/text-generation-inference:1.0.3
        resources:
          limits:
            nvidia.com/gpu: 2
        env:
        - name: MODEL_ID
          value: meta-llama/Llama-2-70b-chat-hf
          # value: TheBloke/Llama-2-70B-chat-GPTQ
        - name: NUM_SHARD
          value: "2"
        - name: PORT 
          value: "8080"
        - name: QUANTIZE
          value: bitsandbytes-nf4
        - name: HUGGING_FACE_HUB_TOKEN
          valueFrom:
            secretKeyRef:
              name: l4-demo
              key: HF_TOKEN
        volumeMounts:
          - mountPath: /dev/shm
            name: dshm
          - mountPath: /data
            name: data
      volumes:
         - name: dshm
           emptyDir:
              medium: Memory
         - name: data
           hostPath:
            path: /mnt/stateful_partition/kube-ephemeral-ssd/llama-data
      nodeSelector:
        cloud.google.com/gke-accelerator: nvidia-l4
```

Create the deployment for serving:
```bash
kubectl apply -f text-generation-interface.yaml
```
