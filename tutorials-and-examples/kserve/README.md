# KServe on GKE Autopilot
KServe is a highly scalable, standards-based platform for model inference on Kubernetes. Installing KServe on GKE Autopilot can be challenging due to the security policies enforced by Autopilot. This tutorial will guide you step by step through the process of installing KServe in a GKE Autopilot cluster.

Additionally, this tutorial includes an example of serving Gemma2 with vLLM in KServe, demonstrating how to utilize GPU resources in KServe on Google Kubernetes Engine (GKE).

## Before you begin

1. Ensure you have a gcp project with billing enabled and [enabled the GKE API](https://cloud.google.com/kubernetes-engine/docs/how-to/enable-gkee). 

2. Ensure you have the following tools installed on your workstation
* [gcloud CLI](https://cloud.google.com/sdk/docs/install)
* [gcloud kubectl](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl#install_kubectl)
* [helm](https://helm.sh/docs/intro/install/)

## Set up your GKE Cluster

1. Set the default environment variables:
```bash
export PROJECT_ID=$(gcloud config get project)
export REGION=us-central1
export CLUSTER_NAME=kserve-demo
```

2. Create a GKE Autopilot cluster:
```bash
gcloud container clusters create-auto ${CLUSTER_NAME} \
    --location=$REGION \
    --project=$PROJECT_ID \
    --workload-policies=allow-net-admin

# Get credentials
gcloud container clusters get-credentials ${CLUSTER_NAME} \
--region ${REGION} \
--project ${PROJECT_ID}
```
If you're using an existing cluster, ensure it is updated to allow net admin permissions. This is necessary for the installation of Istio later on:
```bash
gcloud container clusters update ${CLUSTER_NAME} \
--region=${REGION}
--project=$PROJECT_ID \
--workload-policies=allow-net-admin 
```

## Install KServe
KServe relies on [Knative](https://knative.dev/docs/concepts/) and requires a networking layer. In this tutorial, we will use [Istio](https://istio.io/), the networking layer that integrates best with Knative.

1. Install Knative
```bash
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.15.1/serving-crds.yaml
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.15.1/serving-core.yaml
```

> **Note**: 
> You will see warnings that Autopilot mutated the CRDs during this tutorial. These warnings are safe to ignore.

2. Install Istio
```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
kubectl create namespace istio-system
helm install istio-base istio/base -n istio-system --set defaultRevision=default
helm install istiod istio/istiod -n istio-system --wait
helm install istio-ingressgateway istio/gateway -n istio-system

# Verify the installation
kubectl get deployments -n istio-system

# Example Output
NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
istio-ingressgateway   1/1     1            1           17h
istiod                 1/1     1            1           20h
```

3. Install Knative-Istio
```bash
kubectl apply -f https://github.com/knative/net-istio/releases/download/knative-v1.15.1/net-istio.yaml

# Verify the installation
kubectl get pods -n knative-serving

# Example Output
NAME                                    READY   STATUS    RESTARTS      AGE
activator-749cf94f87-b7p9n              1/1     Running   0             17m
autoscaler-5c764b5f7d-m8zvk             1/1     Running   1 (14m ago)   17m
controller-5649f5bbb7-wvlmk             1/1     Running   4 (13m ago)   17m
net-istio-controller-7f8dfbddb7-d8cmq   1/1     Running   0             18s
net-istio-webhook-54ffc96585-cpgfl      2/2     Running   0             18s
webhook-64c67b4fc-smdtl                 1/1     Running   3 (13m ago)   17m
```

4. Install DNS
In this tutorial we use Magic DNS. To configure a real DNS, follow the steps [here](https://knative.dev/docs/install/yaml-install/serving/install-serving-with-yaml/#__tabbed_2_2).
```bash
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.15.1/serving-default-domain.yaml
```

5. Install [Cert Manager](https://cert-manager.io/docs/installation/), which is required to provision webhook certs for production grade installation.
```bash
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.15.3 --set crds.enabled=true --set global.leaderElection.namespace=cert-manager
```

6. Install Kserve and Kserve cluster runtimes
```bash
kubectl apply -f https://github.com/kserve/kserve/releases/download/v0.14.0-rc0/kserve.yaml

# Wait until kserve-controller-manager is ready
kubectl rollout status deployment kserve-controller-manager -n kserve

# Install cluster runtimes
kubectl apply -f https://github.com/kserve/kserve/releases/download/v0.14.0-rc0/kserve-cluster-resources.yaml

# View these runtimes
kubectl get ClusterServingRuntimes -n kserve
```

7. To request accelerators (GPUs) for your Google Kubernetes Engine (GKE) Autopilot workloads, nodeSelector is used in the manifest. Therefore, we will enable nodeSelector in Knative, which is disabled by default.

```bash
kubectl patch configmap/config-features \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"kubernetes.podspec-nodeselector":"enabled", "kubernetes.podspec-tolerations":"enabled"}}'

# restart knative webhook to consume the config, for example
kubectl get pods -n knative-serving
# Find the webhook pod and delete it to restart the pod.
kubeclt delete pod webhook-64c67b4fc-nmzwt -n knative-serving
```
After successfully installing KServe, you can now explore various examples such as, [first inference service](https://kserve.github.io/website/master/get_started/first_isvc/), [canary rollout](https://kserve.github.io/website/master/modelserving/v1beta1/rollout/canary-example/), inference [batcher](https://kserve.github.io/website/master/modelserving/batcher/batcher/) and [auto-scaling](https://kserve.github.io/website/master/modelserving/autoscaling/autoscaling/).
In the next step, we'll demonstrate how to deploy Gemma2 using vLLM in KServe with GKE Autopilot.

## Deploy Gemma2 served with vllm.
1. Generate a hugging face access token follow [these steps](https://huggingface.co/docs/hub/en/security-tokens). Specify a Name of your choice and a Role of at least **Read**. 

2. Make sure you [accepted the term](https://huggingface.co/google/gemma-2-2b) to use gemma2 in hugging face.

3. Create the hugging face token
```bash
kubectl create namespace kserve-test

# Specify your hugging face token.
export HF_TOKEN = XXX

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
    name: hf-secret
    namespace: kserve-test
type: Opaque
stringData:
    hf_api_token: ${HF_TOKEN}
EOF

```

4. Create the inference service
```bash
kubectl apply -f - <<EOF
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: huggingface-gemma2
  namespace: kserve-test
spec:
  predictor:
    nodeSelector:
      cloud.google.com/gke-accelerator: nvidia-l4
      cloud.google.com/gke-accelerator-count: "1"
    model:
      modelFormat:
        name: huggingface
      args:
        - --enable_docs_url=True
        - --model_name=gemma2
        - --model_id=google/gemma-2-2b
      env:
      - name: HF_TOKEN
        valueFrom:
          secretKeyRef:
            name: hf-secret
            key: hf_api_token
      resources:
        limits:
          cpu: "6"
          memory: 24Gi
          nvidia.com/gpu: "1"
        requests:
          cpu: "6"
          memory: 24Gi
          nvidia.com/gpu: "1"
EOF
```

Wait for the service to be ready:
```bash
kubectl get inferenceservice huggingface-gemma2 -n kserve-test
kubectl get pods -n kserve-test

# Replace pod_name with the correct pod name.
kubectl events --for pod/POD_NAME -n kserve-test --watch
```

## Test the Inference Service
1. Find the URL returned in kubectl get inferenceservice
```bash
URL=$(kubectl get inferenceservice huggingface-gemma2 -o jsonpath='{.status.url}')

# URL should look like this:
http://huggingface-gemma2.kserve-test.34.121.87.225.sslip.io
```

2. Open the swagger UI at $URL/docs

3. Play with the openai chat API with the example input below. Click execute and you can see the response.
```json
{
    "model": "gemma2",
    "messages": [
        {
            "role": "system",
            "content": "You are an assistant that speaks like Shakespeare."
        },
        {
            "role": "user",
            "content": "Write a poem about colors"
        }
    ],
    "max_tokens": 30,
    "stream": false
}
```


## Clean up
Delete the GKE cluster.
```bash
gcloud container clusters delete ${CLUSTER_NAME} \
    --location=$REGION \
    --project=$PROJECT_ID \
```