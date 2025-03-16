# Digital Human for Customer Service on GKE

Deploying the digital human blueprint based on few NIMs on GKE.

## Table of Contents

- [Digital Human for Customer Service on GKE](#digital-human-for-customer-service-on-gke)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Setup](#setup)
  - [Test](#test)
    - [nv-embedqa-e5-v5](#nv-embedqa-e5-v5)
    - [nv-rerankqa-mistral-4b-v3](#nv-rerankqa-mistral-4b-v3)
    - [llama3-8b-instruct](#llama3-8b-instruct)
    - [parakeet-ctc-1.1b-asr](#parakeet-ctc-11b-asr)
    - [fastpitch-hifigan-tts](#fastpitch-hifigan-tts)
    - [audio2face-2d](#audio2face-2d)
    - [audio2face-3d](#audio2face-3d)
  - [Tear down](#tear-down)

## Prerequisites

- **GCloud SDK:** Ensure you have the Google Cloud SDK installed and configured.
- **Project:**  A Google Cloud project with billing enabled.
- **NGC API Key:** An API key from NVIDIA NGC. Please read the prerequisites to access this key [here](https://github.com/NVIDIA-AI-Blueprints/digital-human/blob/main/README.md#prerequisites)
- **kubectl:**  kubectl command-line tool installed and configured.
- **NVIDIA GPUs:** One of the below GPUs should work
  - [NVIDIA L4 GPU (8)](https://cloud.google.com/compute/docs/gpus#l4-gpus)
  - [NVIDIA A100 80GB (1) GPU](https://cloud.google.com/compute/docs/gpus#a100-gpus)
  - [NVIDIA H100 80GB (1) GPU or higher](https://cloud.google.com/compute/docs/gpus#a3-series)

## Setup

1. **Environment setup**: You'll set up several environment variables to make the following steps easier and more flexible. These variables store important information like cluster names, machine types, and API keys. You need to update the variable values to match your needs and context.

    ```bash
    gcloud config set project "<GCP Project ID>"

    export CLUSTER_NAME="gke-nimbp-dighuman"
    export NP_NAME="gke-nimbp-dighuman-gpunp"

    export ZONE="us-west4-a"            # e.g., us-west4-a
    export NP_CPU_MACHTYPE="e2-standard-2" # e.g., e2-standard-2
    export NP_GPU_MACHTYPE="g2-standard-96" # e.g., a2-ultragpu-1g

    export ACCELERATOR_TYPE="nvidia-l4"     # e.g., nvidia-a100-80gb
    export ACCELERATOR_COUNT="8"            # Or higher, as needed
    export NODE_POOL_NODES=1                # Or higher, as needed

    export NGC_API_KEY="<NGC API Key>"
    ```

2. **GKE Cluster and Node pool creation**:

    ```bash
    gcloud container clusters create "${CLUSTER_NAME}" \
      --num-nodes="1" \
      --location="${ZONE}" \
      --machine-type="${NP_CPU_MACHTYPE}" \
      --addons=GcpFilestoreCsiDriver

    gcloud container node-pools create "${NP_NAME}" \
      --cluster="${CLUSTER_NAME}" \
      --location="${ZONE}" \
      --node-locations="${ZONE}" \
      --num-nodes="${NODE_POOL_NODES}" \
      --machine-type="${NP_GPU_MACHTYPE}" \
      --accelerator="type=${ACCELERATOR_TYPE},count=${ACCELERATOR_COUNT},gpu-driver-version=LATEST" \
      --placement-type="COMPACT" \
      --disk-type="pd-ssd" \
      --disk-size="300GB"
    ```

3. **Get Cluster Credentials:**

    ```bash
    gcloud container clusters get-credentials "${CLUSTER_NAME}" --location="${ZONE}"
    ```

4. **Set kubectl Alias (Optional):**

    ```bash
    alias k=kubectl
    ```

5. **Create NGC API Key Secret:** Creates secrets for pulling images from NVIDIA NGC and pods that need the API key at startup.

    ```bash
    k create secret docker-registry secret-nvcr \
      --docker-username=\$oauthtoken \
      --docker-password="${NGC_API_KEY}" \
      --docker-server="nvcr.io"

    k create secret generic ngc-api-key \
      --from-literal=NGC_API_KEY="${NGC_API_KEY}"
    ```

6. **Deploy NIMs:**

    ```bash
    k apply -f digital-human-nimbp.yaml
    ```

    The NIM deployment takes upto 15mins for it to be complete. You can check the pods are in `Running` status: `k get pods` should list below pods.

    | NAME | READY | STATUS | RESTARTS |
    |---|---|---|---|
    |`dighum-embedqa-e5v5-aa-aa` | 1/1 | Running | 0 |
    |`dighum-rerankqa-mistral4bv3-bb-bb` | 1/1 | Running | 0 |
    |`dighum-llama3-8b-cc-cc` | 1/1 | Running | 0 |
    |`dighum-audio2face-3d-dd-dd` | 1/1 | Running | 0 |
    |`dighum-fastpitch-tts-ee-ee` | 1/1 | Running | 0 |
    |`dighum-maxine-audio2face-2d-ff-ff` | 1/1 | Running | 0 |
    |`dighum-parakeet-asr-1-1b-gg-gg` | 1/1 | Running | 0 |

4. **Access NIM endpoints**

    ```bash
    SERVICES=$(k get svc | awk '{print $1}' | grep -v NAME | grep '^dighum')

    for service in $SERVICES; do
      # Get the pod name.
      POD=$(k get pods -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep $(echo $service | sed 's/-lb//'))

      # Get external IP.
      EXTERNAL_IP=$(k get svc $service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

      echo "----------------------------------"
      echo "Testing service: $service at ${EXTERNAL_IP}"
      curl http://${EXTERNAL_IP}/v1/health/ready
      echo " "
      echo "----------------------------------"
    done
    ```

    [Click here if you need HTTPS endpoints](https.md)

## Test

   Below are curl statements to test each of the endpoints

### nv-embedqa-e5-v5

   Set `EXTERNAL_IP` from above output for `dighum-embedqa-e5v5`

    ```bash
    export EXTERNAL_IP=<IP>
    curl -X "POST" \
    "http://${EXTERNAL_IP}/v1/embeddings" \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json' \
      -d '{
      "input": ["Hello world"],
      "model": "nvidia/nv-embedqa-e5-v5",
      "input_type": "query"
    }'
    ```

### nv-rerankqa-mistral-4b-v3

    Set `EXTERNAL_IP` from above output for `dighum-rerankqa-mistral4bv3`

    ```bash
    export EXTERNAL_IP=<IP>

    curl -X "POST" \
    "http://${EXTERNAL_IP}/v1/ranking" \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json' \
    -d '{
    "model": "nvidia/nv-rerankqa-mistral-4b-v3",
    "query": {"text": "which way should i go?"},
    "passages": [
      {"text": "two roads diverged in a yellow wood, and sorry i could not travel both and be one traveler, long i stood and looked down one as far as i could to where it bent in the undergrowth;"}
    ],
    "truncate": "END"
    }'
    ```

### llama3-8b-instruct

   Set `EXTERNAL_IP` from above output for `dighum-llama3-8b`

    ```bash
    export EXTERNAL_IP=<IP>

    curl -X "POST" \
    "http://${EXTERNAL_IP}/v1/chat/completions" \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json' \
    -d '{
    "model": "meta/llama3-8b-instruct",
    "messages": [{"role":"user", "content":"Write a limerick about the wonders of GPU computing."}],
      "max_tokens": 64
    }'
    ```

### parakeet-ctc-1.1b-asr

- Install the Riva Python client package

   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install nvidia-riva-client
  ```

- Download Riva sample clients

    ```bash

    git clone https://github.com/nvidia-riva/python-clients.git

    ```

- Run Speech to Text inference in streaming modes. Riva ASR supports Mono, 16-bit audio in WAV, OPUS and FLAC formats.

    ```bash
 
    k port-forward $(k get pod --selector="app=dighum-parakeet-asr-1-1b" --output jsonpath='{.items[0].metadata.name}') 50051:50051

    python3 python-clients/scripts/asr/transcribe_file.py --server 0.0.0.0:50051 --input-file ./output.wav --language-code en-US

    deactivate

    ```

 For more details on getting started with this NIM, visit the [Riva ASR NIM Docs](https://docs.nvidia.com/nim/riva/asr/latest/overview.html)

### fastpitch-hifigan-tts

- Install the Riva Python client package

   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install nvidia-riva-client
  ```

- Download Riva sample clients

  ```bash
 
  git clone https://github.com/nvidia-riva/python-clients.git

  ```

- Use `kubectl` to port forward

  ```bash

  k port-forward $(k get pod --selector="app=dighum-parakeet-asr-1-1b" --output jsonpath='{.items[0].metadata.name}') 50051:50051 &

  ```

- Run Speech to Text inference in streaming modes. Riva ASR supports Mono, 16-bit audio in WAV, OPUS and FLAC formats.

  ```bash
  python3 python-clients/scripts/tts/talk.py --server 0.0.0.0:50051 --text "Hello, this is a speech synthesizer." --language-code en-US --output output.wav

  deactivate
  ```

 On running the above command, the synthesized audio file named output.wav will be created.

### audio2face-2d

- Setup a virtual env

   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

- Download the Audio2Face-2D client code

  ```bash
  git clone https://github.com/NVIDIA-Maxine/nim-clients.git
  cd nim-clients/audio2face-2d/
  pip install -r python/requirements.txt
  ```

- Compile the protos

  ```bash
  cd protos/linux/python
  chmod +x compile_protos.sh
  ./compile_protos.sh
  ```

- Run test inference

  ```bash
  cd python/scripts
  
  python audio2face-2d.py --target <server_ip:port> \
    --audio-input <input audio file path> \
    --portrait-input <input portrait image file path> \
    --output <output file path and the file name> \
    --head-rotation-animation-filepath <rotation animation filepath> \
    --head-translation-animation-filepath <translation animation filepath> \
    --ssl-mode <ssl mode value> \
    --ssl-key <ssl key file path> \
    --ssl-cert <ssl cert filepath> \
    --ssl-root-cert <ssl root cert filepath>
  ```

   Refer the documentation [audio2face-2d](https://docs.nvidia.com/nim/maxine/audio2face-2d/latest/basic-inference.html#running-inference-via-node-js-script) NIM to set the values.

### audio2face-3d

- Setup a virtual env

   ```bash
   python3 -m venv venv
   source venv/bin/activate
  ```

- Download the Audio2Face-2D client code

  ```bash
  git clone https://github.com/NVIDIA/Audio2Face-3D-Samples.git
  cd Audio2Face-3D-Samples/scripts/audio2face_3d_microservices_interaction_app

  pip3 install ../../proto/sample_wheel/nvidia_ace-1.2.0-py3-none-any.whl

  pip3 install -r requirements.txt
  ```

- Perform a health check

  ```bash
  python3 a2f_3d.py health_check --url 0.0.0.0:52000
  ```

- Run a test inference

  ```bash
  python3 a2f_3d.py run_inference ../../example_audio/Claire_neutral.wav config/config_claire.yml \
  -u 0.0.0.0:52000
  ```

  Refer the documentation of [audio2face-3d](https://docs.nvidia.com/ace/audio2face-3d-microservice/latest/text/getting-started/getting-started.html#running-inference) NIM for more information.

## Tear down

  **Tear down the environment**
  **NOTE:** Please note all the NIMs deployed and cluster will be deleted.

  ```bash
    k delete -f digital-human-nimbp.yaml
    k delete secret secret-nvcr
    k delete secret ngc-api-key
    gcloud container clusters delete "${CLUSTER_NAME}" \
    --location="${ZONE}" --quiet
  ```
