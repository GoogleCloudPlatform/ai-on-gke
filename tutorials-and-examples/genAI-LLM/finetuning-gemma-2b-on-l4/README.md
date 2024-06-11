# Tutorial: Finetuning Gemma 2b on GKE using L4 GPUs

We’ll walk through fine-tuning a Gemma 2b model using GKE using 8 x L4 GPUs. L4 GPUs are suitable for many use cases beyond serving models. We will demonstrate how the L4 GPU is a great option for fine tuning LLMs, at a fraction of the cost of using a higher end GPU.

Let’s get started and fine-tune Gemma 2B on the [b-mc2/sql-create-context](https://huggingface.co/datasets/b-mc2/sql-create-context) dataset using GKE.
Parameter Efficient Fine Tuning (PEFT) and LoRA is used so fine-tuning is posible
on GPUs with less GPU memory.

As part of this tutorial, you will get to do the following:

1. Prepare your environment with a GKE cluster in
    Autopilot mode.
2. Create a finetune container.
3. Use GPU to finetune the Gemma 2B model and upload the model to huggingface.

## Prerequisites

* A terminal with `kubectl` and `gcloud` installed. Cloud Shell works great!
* Create a [Hugging Face](https://huggingface.co/) account, if you don't already have one.
* Ensure your project has sufficient quota for GPUs. To learn more, see [About GPUs](/kubernetes-engine/docs/concepts/gpus#gpu-quota) and [Allocation quotas](/compute/resource-usage#gpu_quota).
* To get access to the Gemma models for deployment to GKE, you must first sign the license consent agreement then generate a Hugging Face access token. Make sure the token has `Write` permission.

## Creating the GKE cluster with L4 nodepools

Let’s start by setting a few environment variables that will be used throughout this post. You should modify these variables to meet your environment and needs. 

Download the code and files used throughout the tutorial:

```bash
git clone https://github.com/GoogleCloudPlatform/ai-on-gke
cd ai-on-gke/tutorials-and-examples/genAI-LLM/finetuning-gemma-2b-on-l4
```

Run the following commands to set the env variables and make sure to replace `<my-project-id>`:

```bash
gcloud config set project <my-project-id>
export PROJECT_ID=$(gcloud config get project)
export REGION=us-central1
export HF_TOKEN=<YOUR_HF_TOKEN>
export CLUSTER_NAME=finetune-gemma
```

> Note: You might have to rerun the export commands if for some reason you reset your shell and the variables are no longer set. This can happen for example when your Cloud Shell disconnects.

Create the GKE cluster by running:

```bash
gcloud container clusters create-auto ${CLUSTER_NAME} \
  --project=${PROJECT_ID} \
  --region=${REGION} \
  --release-channel=rapid \
  --cluster-version=1.29
```

### Create a Kubernetes secret for Hugging Face credentials

In your shell session, do the following:

  1. Configure `kubectl` to communicate with your cluster:

      ```sh
      gcloud container clusters get-credentials ${CLUSTER_NAME} --location=${REGION}
      ```

  2. Create a Kubernetes Secret that contains the Hugging Face token:

      ```sh
      kubectl create secret generic hf-secret \
        --from-literal=hf_api_token=${HF_TOKEN} \
        --dry-run=client -o yaml | kubectl apply -f -
      ```

### Containerize the Code with Docker and Cloud Build

1. Create an Artifact Registry Docker Repository

    ```sh
    gcloud artifacts repositories create gemma \
        --project=${PROJECT_ID} \
        --repository-format=docker \
        --location=us \
        --description="Gemma Repo"
    ```

2. Execute the build and create inference container image.

    ```sh
    gcloud builds submit .
    ```

## Run Finetune Job on GKE

1. Open the `finetune.yaml` manifest.
2. Edit the `image` name with the container image built with Cloud Build and `NEW_MODEL` environment variable value. This `NEW_MODEL` will be the name of the model you would save as a public model in your Hugging Face account.
3. Run the following command to create the finetune job:

    ```sh
    kubectl apply -f finetune.yaml
    ```

4. Monitor the job by running:

    ```sh
    watch kubectl get pods
    ```

5. You can check the logs of the job by running:

    ```sh
    kubectl logs -f -l app=gemma-finetune
    ```

6. Once the job is completed, you can check the model in Hugging Face.

## Serve the Finetuned Model on GKE

To deploy the finetuned model on GKE you can follow the instructions from Deploy a pre-trained Gemma model on [Hugging Face TGI](https://cloud.google.com/kubernetes-engine/docs/tutorials/serve-gemma-gpu-tgi#deploy-pretrained) or [vLLM](https://cloud.google.com/kubernetes-engine/docs/tutorials/serve-gemma-gpu-vllm#deploy-vllm). Select the Gemma 2B instruction and change the `MODEL_ID` to `<YOUR_HUGGING_FACE_PROFILE>/gemma-2b-sql-finetuned`.

### Set up port forwarding

Once the model is deploye, run the following command to set up port forwarding to the model:

```sh
kubectl port-forward service/llm-service 8000:8000
```

The output is similar to the following:

```sh
Forwarding from 127.0.0.1:8000 -> 8000
```

### Interact with the model using curl

Once the model is deployed In a new terminal session, use curl to chat with your model:

> The following example command is for TGI.

```sh
USER_PROMPT="Question: What is the total number of attendees with age over 30 at kubecon eu? Context: CREATE TABLE attendees (name VARCHAR, age INTEGER, kubecon VARCHAR)"

curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d @- <<EOF
{
    "inputs": "${USER_PROMPT}",
    "parameters": {
        "temperature": 0.1,
        "top_p": 0.95,
        "max_new_tokens": 25
    }
}
EOF
```

The following output shows an example of the model response:

```sh
{"generated_text":" Answer: SELECT COUNT(age) FROM attendees WHERE age > 30 AND kubecon = 'eu'\n"}
```

## Clean Up

To avoid incurring charges to your Google Cloud account for the resources used in this tutorial, either delete the project that contains the resources, or keep the project and delete the individual resources.

### Delete the deployed resources

To avoid incurring charges to your Google Cloud account for the resources that you created in this guide, run the following command:

```sh
gcloud container clusters delete ${CLUSTER_NAME} \
  --region=${REGION}
```
