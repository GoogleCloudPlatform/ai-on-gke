# High-performance diffusion model inference on GKE and TPU using MaxDiffusion

## About MaxDiffusion
Just as LLMs have revolutionized natural language processing, diffusion models are transforming the field of computer vision. To reduce our customers’ costs of deploying these models, Google created MaxDiffusion: a collection of open-source diffusion-model reference implementations. These implementations are written in JAX and are highly performant, scalable, and customizable – think MaxText for computer vision. 

MaxDiffusion provides high-performance implementations of core components of diffusion models such as cross attention, convolutions, and high-throughput image data loading. MaxDiffusion is designed to be highly adaptable and customizable: whether you're a researcher pushing the boundaries of image generation or a developer seeking to integrate cutting-edge gen AI capabilities into your applications, MaxDiffusion provides the foundation you need to succeed.

## Prerequisites
Access to a Google Cloud project with the TPU v5e available and enough quota in the region you select. In the walk-through, we only choose lower end TPU v5e, single host with 1x1 chips

A computer terminal with kubectl and the Google Cloud SDK installed. From the GCP project console you’ll be working with, you may want to use the included Cloud Shell as it already has the required tools installed.

MaxDiffsusion will access Huggingface to download Stable Diffusion XL model(stabilityai/stable-diffusion-xl-base-1.0), while no huggingface access token required for access

### Setup project environments
Set the project and region that have availability for TPU v5e( alternatively, you can choose other regions with different TPU v5e accelerator type available):

```
export PROJECT_ID=<your-project-id>
export REGION=us-east1
export ZONE_1=${REGION}-c # You may want to change the zone letter based on the region you selected above

export CLUSTER_NAME=tpu-cluster
gcloud config set project "$PROJECT_ID"
gcloud config set compute/region "$REGION"
gcloud config set compute/zone "$ZONE_1"
```
Then, enable the required APIs to create a GK cluster:
```
gcloud services enable compute.googleapis.com container.googleapis.com
```

Also, you may go ahead download the source code repo for this exercise, :
```
git clone https://github.com/GoogleCloudPlatform/ai-on-gke.git
cd tutorials-and-examples/tpu-examples/maxdiffusion
```
## Create GKE Cluster and Nodepools
### GKE Cluster

Now, create a GKE cluster with a minimal default node pool, as you will be adding a node pool with TPU v5e later on:
```
gcloud container clusters create $CLUSTER_NAME --location ${REGION} \
  --workload-pool ${PROJECT_ID}.svc.id.goog \
  --enable-image-streaming --enable-shielded-nodes \
  --shielded-secure-boot --shielded-integrity-monitoring \
  --enable-ip-alias \
  --node-locations=$REGION-b \
  --workload-pool=${PROJECT_ID}.svc.id.goog \
  --addons GcsFuseCsiDriver   \
  --no-enable-master-authorized-networks \
  --machine-type n2d-standard-4 \
  --cluster-version 1.29 \
  --num-nodes 1 --min-nodes 1 --max-nodes 3 \
  --ephemeral-storage-local-ssd=count=2 \
  --scopes="gke-default,storage-rw"
```

### Nodepool
Create an additional Spot node pool (we use spot to save costs, you can remove spot option depends on different use case) with TPU accelerator:

```
cloud container node-pools create $CLUSTER_NAME-tpu \
--location=$REGION --cluster=$CLUSTER_NAME --node-locations=$ZONE_1 \
--machine-type=ct5lp-hightpu-1t --num-nodes=0 --spot --node-version=1.29 \
--ephemeral-storage-local-ssd=count=0 --enable-image-streaming \
--shielded-secure-boot --shielded-integrity-monitoring \
--enable-autoscaling --total-min-nodes 0 --total-max-nodes 2 --location-policy=ANY
```

Note how easy enabling TPU in GKE nodepool with proper TPU machine type. Please refer to the following page, for details on TPU v5e machine type and configuration sections.

After a few minutes, check that the node pool was created correctly:
```
gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION --project $PROJECT_ID
gcloud container node-pools list --region $REGION --cluster $CLUSTER_NAME
```

## Explaination on MaxDiffusion inference server sample code
The sample Stable Diffusion XL inference [code template](https://github.com/google/maxdiffusion/blob/main/src/maxdiffusion/generate_sdxl_replicated.py) from MaxDiffusion repo is updated with FastAPI and uvicorn libraries to fit for API requests.

The updated Stable Diffusion XL Inference [Code sample](https://github.com/GoogleCloudPlatform/ai-on-gke.git/blob/main/tutorials-and-examples/tpu-examples/maxdiffusion/build/server/main.py) provided here for reference.

### Add FastAPI and Uvicorn libraries
### Add logging, health check
### Expose /generate as Post methods for REST API requests
### HuggingFace Stable Diffusion XL Model: stabilityai/stable-diffusion-xl-base-1.0

To make the Stable Diffusion XL inference more efficient, we compile the pipeline._generate function, and pass all parameters to the function and tell JAX which are static arguments,

default_seed = 33

default_guidance_scale = 5.0

default_num_steps = 40

width = 1024

height = 1024

The following main exposed SDXL inference method,

```
@app.post("/generate")
async def generate(request: Request):
    LOG.info("start generate image")
    data = await request.json()
    prompt = data["prompt"]
    LOG.info(prompt)
    prompt_ids, neg_prompt_ids = tokenize_prompt(prompt, default_neg_prompt)
    prompt_ids, neg_prompt_ids, rng = replicate_all(prompt_ids, neg_prompt_ids, default_seed)
    g = jnp.array([default_guidance_scale] * prompt_ids.shape[0], dtype=jnp.float32)
    g = g[:, None]
    LOG.info("call p_generate")
    images = p_generate(prompt_ids, p_params, rng, g, None, neg_prompt_ids)

    # convert the images to PIL
    images = images.reshape((images.shape[0] * images.shape[1],) + images.shape[-3:])
    images=pipeline.numpy_to_pil(np.array(images))
    buffer = io.BytesIO()
    LOG.info("Save image")
    for i, image in enumerate(images):
        if i==0:
          image.save(buffer, format="PNG")
    #await images[0].save(buffer, format="PNG")

    # Return the image as a response
    return Response(content=buffer.getvalue(), media_type="image/png")

if __name__ == "__main__":
   uvicorn.run(app, host="0.0.0.0", port=8000, reload=False, log_level="debug")
```

## Build Stable Diffusion XL Inference Container Image
Next, let’s build the Inference server container image with cloud build.

Sample Docker file and cloudbuild.yaml already under directory buid/server/ downloaded repo,

buid/server/Dockerfile:
```
FROM python:3.11-slim
WORKDIR /app
RUN apt-get -y update
RUN apt-get -y install git
COPY requirements.txt ./
RUN python -m pip install --upgrade pip
RUN pip install -U "jax[tpu]" -f https://storage.googleapis.com/jax-releases/libtpu_releases.html
RUN pip install -r requirements.txt
RUN pip install git+https://github.com/google/maxdiffusion.git
COPY main.py ./
EXPOSE 8000
ENTRYPOINT ["python", "main.py"]
```
Notes: we may not have maxdiffusion pip package to be downloaded yet, thus, RUN pip install git+https://github.com/google/maxdiffusion.git is used to download MaxDiffusion from source directly.

cloudbuild.yaml:
```
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: [ 'build', '-t', 'us-east1-docker.pkg.dev/$PROJECT_ID/gke-llm/max-diffusion:latest', '.' ]
images:
- 'us-east1-docker.pkg.dev/$PROJECT_ID/gke-llm/max-diffusion:latest'
```

Note: replace destination of container image as your own environment

Run the following commands to kick of container image builds:
```
cd build/server
gcloud builds submit .
```

## Deploy Stable Diffusion XL Inference Server in GKE
In the downloaded code repo root directory, you can check the following kubernetes deployment resource files,

serve_sdxl_v5e.yaml:
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stable-diffusion-deployment
spec:
  selector:
    matchLabels:
      app: max-diffusion-server
  replicas: 1  # number of nodes in node-pool
  template:
    metadata:
      labels:
        app: max-diffusion-server
    spec:
      nodeSelector:
        cloud.google.com/gke-tpu-topology: 1x1 #  target topology
        cloud.google.com/gke-tpu-accelerator: tpu-v5-lite-podslice
      volumes:
       - name: dshm
         emptyDir:
              medium: Memory
      containers:
      - name: serve-stable-diffusion
        image: us-east1-docker.pkg.dev/rick-vertex-ai/gke-llm/max-diffusion:latest
        securityContext:
          privileged: true
        env:
        - name: MODEL_NAME
          value: 'stable_diffusion'
        ports:
        - containerPort: 8000
        resources:
          requests:
            google.com/tpu: 1  # TPU chip request
          limits:
            google.com/tpu: 1  # TPU chip request
        volumeMounts:
            - mountPath: /dev/shm
              name: dshm

---
apiVersion: v1
kind: Service
metadata:
  name: max-diffusion-server
  labels:
    app: max-diffusion-server
spec:
  type: ClusterIP
  ports:
    - port: 8000
      targetPort: http
      name: http-max-diffusion-server
  selector:
    app: max-diffusion-server
```

To be noted, in deployment specs settings related to TPU accelerators which has to match v5e machine types (ct5lp-hightpu-1t has 1x1=1 total TPU chips):
```
nodeSelector:
        cloud.google.com/gke-tpu-topology: 1x1 #  target topology
        cloud.google.com/gke-tpu-accelerator: tpu-v5-lite-podslice

resources:
          requests:
            google.com/tpu: 1  # TPU chip request
          limits:
            google.com/tpu: 1  # TPU chip request
```
We use type: ClusterIP to expose inference service availabe to GKE cluster only. Update this file with proper container image name and location,

Run the following command to deploy Stable Diffusion Inference server to GKE:
```
gcloud container clusters get-credentials $CLUSTER_NAME $REGION
kubectl apply -f serve_sdxl_v5e.yaml
kubectl get svc max-diffusion-server. 
```

It may take 7–8 minutes to wait for the spot nodepool provisioning, model loading and initial pipeline compilation. Note the service IP need to be referenced by later section

You may use the following command to validate Stable Diffusion Inference Server setup properly,
```
SERVER_URL=XXXX
kubectl run -it busybox --image radial/busyboxplus:curl


curl SERVER_URL:8000
```
If you have issues such as connection refused in curl command validations, you may use the following command instead to create a service through kubectl command:
```
kubectl expose deployment max-diffusion-deployment max-diffusion-service --port 8000 --protocol tcp --target-port 8000

```

## Deploy WebApp
A simple client webapp provided under build/webapp directory with following files included:

app.py ( main python file), Dockerfile , cloudbuild.yaml , requirements.txt

You may update cloudbuild.yaml file with your own container image destination accordingly.

Run the following command to build testing webapp container image using cloud build:
```
cd build/webapp
gcloud builds submit .
```
Once the webapp image build completed, you may go ahead deploy frontend webapp to test Stable Diffusion XL inference server.

serve_sdxl_client.yaml:
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: max-diffusion-client
spec:
  selector:
    matchLabels:
      app: max-diffusion-client
  template:
    metadata:
      labels:
        app: max-diffusion-client
    spec:
      containers:
      - name: webclient
        image: us-east1-docker.pkg.dev/rick-vertex-ai/gke-llm/max-diffusion-client:latest
        env:
          - name: SERVER_URL
            value: "http://CLusterIP:8000"
        resources:
          requests:
            memory: "128Mi"
            cpu: "250m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        ports:
        - containerPort: 5000
---
apiVersion: v1
kind: Service
metadata:
  name: max-diffusion-client-service
spec:
  type: LoadBalancer
  selector:
    app: max-diffusion-client
  ports:
  - port: 8080
    targetPort: 5000
```
We use type: LoadBalancer to expose webapp to external public. Update this file with proper container image name and SERVER_URL endpoint location from. Run the following command to deploy frontend webapp:

```
kubectl apply -f serve_sdxl_client.yaml
```
Once the webapp deployment completed, you may test text to image capabilities from browser:
http://webappServiceIP:8080/

Image generated after 3–5s( displaying only first image from inference), which is quite performance efficient for Cloud TPU v5e based on Single-host serving for one single v5e chips.

## Cleanups
Don’t forget to clean up the resources created in this article once you’ve finished experimenting with Stable Diffusion inference on GKE and TPU, as keeping the cluster running for a long time can incur in important costs. To clean up, you just need to delete the GKE cluster:
```
gcloud container clusters delete $CLUSTER_NAME - region $REGION
```
## Conclusion
With the streamlined process showcased in this post, deploying inference servers for open-source image generation/vision models like Stable Diffusion XL on GKE and TPU has never been simpler or more efficient with MaxDiffusion to serve JAX models directly, without need for download and conversion JAX model to Tensorflow compatible model for Stable Diffusion Inference Serving in GKE and TPU

Don’t forget to check out other GKE related resources on AI ML infrastructure offered by Google Cloud and check the resources included in the AI/ML orchestration on GKE documentation.

The [blog](https://medium.com/google-cloud/high-performance-stable-diffusion-xl-inference-on-gke-and-tpu-with-maxdiffusion-97a786c06257) published linked to this repo