1. Set env vars
```
export REGION=us-central1
export PROJECT_ID=$(gcloud config get project)
```
2. Create cluster
```
gcloud container clusters create l4-demo --location ${REGION}   \
--workload-pool ${PROJECT_ID}.svc.id.goog   --enable-image-streaming \
--node-locations=$REGION-a --addons GcsFuseCsiDriver  \
 --machine-type n2d-standard-4  \
 --num-nodes 1 --min-nodes 1 --max-nodes 5   \
--ephemeral-storage-local-ssd=count=2 --enable-ip-alias
```
```
kubectl config set-cluster l4-demo
```
3. Create node pool
```
gcloud container node-pools create g2-standard-24 --cluster l4-demo \
  --accelerator type=nvidia-l4,count=2,gpu-driver-version=latest \
  --machine-type g2-standard-24 \
  --ephemeral-storage-local-ssd=count=2 \
 --enable-image-streaming \
 --num-nodes=1 --min-nodes=1 --max-nodes=2 \
 --node-locations $REGION-a,$REGION-b --region $REGION
 ```
4. Set the project_id in workloads.tfvars and create the application: `terrafrom apply -var-file=workloads.tfvars` 
5. Make sure app started ok: `kubectl logs -l app=mistral-7b-instruct`
6. Set up port forward
```
kubectl port-forward deployment/mistral-7b-instruct 8080:8080 &
```
7. Try a few prompts:
```
export USER_PROMPT="How to deploy a container on K8s?"
```
```
curl 127.0.0.1:8080/generate -X POST \
    -H 'Content-Type: application/json' \
    --data-binary @- <<EOF
{
    "inputs": "[INST] <<SYS>>\nYou are a helpful, respectful and honest assistant. Always answer as helpfully as possible, while being safe.  Your answers should not include any harmful, unethical, racist, sexist, toxic, dangerous, or illegal content. Please ensure that your responses are socially unbiased and positive in nature. If a question does not make any sense, or is not factually coherent, explain why instead of answering something not correct. If you don't know the answer to a question, please don't share false information.\n<</SYS>>\n$USER_PROMPT[/INST]",
    "parameters": {"max_new_tokens": 400}
}
EOF
```
8. Look at `/metrics` endpoint of the service. Go to cloud monitoring and search for one of those metrics. For example, `tgi_request_count` or `tgi_batch_inference_count`. Those metrics should show up if you search for them in PromQL. 

9. Clean up the cluster
```
gcloud container clusters delete l4-demo --location ${REGION} 
```