# Tutorial: Serving Llama 2 70b on GKE L4 GPUs
Learn how to serve Llama 2 70b chat model on GKE using just 2 x L4 GPUs. For
this post the text-generation-inference project is used for serving.

### Prerequisites
*   A terminal with `kubectl` and `gcloud` installed. Cloud Shell works great!
*   L4 GPUs quota to be able to run additional 2 L4 GPUs
*   Request access to Meta Llama models by submitting the [request access form](https://ai.meta.com/resources/models-and-libraries/llama-downloads/)
*   Agree to the Llama 2 terms on the [Llama 2 70B Chat HF](https://huggingface.co/meta-llama/Llama-2-70b-chat-hf) model in HuggingFace

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

Hugging Face requires authentication to download the [Llama-2-70b-chat-hf](https://huggingface.co/meta-llama/Llama-2-70b-chat-hf) model, which means an access token is required to download the model.

You can get your access token from [huggingface.com > Settings > Access Tokens](https://huggingface.co/settings/tokens). Afterwards, set your HuggingFace token as an environment variable:
```bash
export HF_TOKEN=<paste-your-own-token>
```

Create a Secret to store your HuggingFace token which will be used by the K8s job:
```bash
kubectl create secret generic l4-demo --from-literal="HF_TOKEN=$HF_TOKEN"
```

Create a file named `text-generation-interface.yaml` with the following content:
[embedmd]:# (text-generation-interface.yaml)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llama-2-70b
spec:
  replicas: 1
  selector:
    matchLabels:
      app: llama-2-70b
  template:
    metadata:
      labels:
        app: llama-2-70b
    spec:
      containers:
      - name: llama-2-70b
        image: ghcr.io/huggingface/text-generation-inference:1.0.3
        resources:
          limits:
            nvidia.com/gpu: 2
        env:
        - name: MODEL_ID
          value: meta-llama/Llama-2-70b-chat-hf
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
Check the logs and make sure there are no errors:
```bash
kubectl logs -l app=llama-2-70b
```

Now it's time to test it out by sending it some prompts.
Setup port forwarding to the inferencing server:
```bash
kubectl port-forward deployment/llama-2-70b 8080:8080
```

Now you can chat with your model through a simple curl:
```bash
curl 127.0.0.1:8080/generate -X POST \
    -H 'Content-Type: application/json' \
    --data-binary @- <<EOF
{
    "inputs": "[INST] <<SYS>>\nYou are a helpful, respectful and honest assistant. Always answer as helpfully as possible, while being safe.  Your answers should not include any harmful, unethical, racist, sexist, toxic, dangerous, or illegal content. Please ensure that your responses are socially unbiased and positive in nature. If a question does not make any sense, or is not factually coherent, explain why instead of answering something not correct. If you don't know the answer to a question, please don't share false information.\n<</SYS>>\nHow to deploy a container on K8s?[/INST]",
    "parameters": {"max_new_tokens": 400}
}
EOF
```

There are also API docs available at [http://localhost:8080/docs](http://localhost:8080/docs).
