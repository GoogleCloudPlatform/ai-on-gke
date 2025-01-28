# Chatbot Application with LangChain, Persistent Storage and IAP

- [Introduction](#introduction)
  - [What is LangChain](#what-is-langchain)
  - [What is Streamlit](#what-is-streamlit)
  - [What is Identity Aware Proxy (IAP)](#what-is-identity-aware-proxy-iap)
- [Prerequisites](#prerequisites)
- [Optional: Build and Run the Application Locally](#optional-build-and-run-the-application-locally)
- [Prepare the Application for Deployment](#prepare-the-application-for-deployment)
  - [Create Google Container Registry (GCR)](#create-google-container-registry-gcr)
  - [Build the Application Using Cloud Build](#build-the-application-using-cloud-build)
  - [Enable IAP and create OAuth client](#enable-iap-and-create-oauth-client)
- [Manual Deployment](#manual-deployment)
  - [Create Cloud SQL Instance](#create-cloud-sql-instance)
  - [Deploy the application to GKE](#deploy-the-application-to-gke)
  - [Expose the application to the internet](#expose-the-application-to-the-internet)
  - [Configure IAP for the application](#configure-iap-for-the-application)
- [Automated Deployment](#automated-deployment)
- [Interaction with the Chatbot](#interaction-with-the-chatbot)
- [Conclusion](#conclusion)

## Introduction

It is important to make AI models accessible to end-users through applications that provide a user-friendly interface.

In this tutorial, you will learn how to deploy a chatbot application using LangChain and Streamlit on Google Cloud Platform (GCP).

The application can be used to interact with any language model served on an OpenAI-compatible API; for example, you can use the Gemma2 model deployed on Google Kubernetes Engine (GKE) using Kserve, as described in the [Kserve README](../kserve/README.md).

The application will be deployed on GCP using Terraform and secured with Identity Aware Proxy (IAP).

Finally, it will use user identity provided by IAP and store each user's messages in a Cloud SQL PostgreSQL database.

### What is LangChain

LangChain is a framework designed to simplify the integration of language models into applications. It provides tools and abstractions to manage the complexities of working with language models, making it easier to build, deploy and maintain AI-powered applications.

### What is Streamlit

Streamlit is an open-source app framework used to create interactive web applications for machine learning and data science projects. It allows developers to build and deploy powerful data-driven applications with minimal effort.

### What is Identity Aware Proxy (IAP)

Identity Aware Proxy (IAP) is a Google Cloud service that provides secure access to applications running on GCP. It allows you to control access to your applications based on user identity, ensuring that only authorized users can access your resources. You can learn more about IAP [here](https://cloud.google.com/iap).

## Prerequisites

This tutorial assumes you have the following:

- A Google Cloud Platform account and project
- The Google Cloud SDK (gcloud) installed and configured
- The Kubernetes command-line tool (kubectl) installed and configured
- An instruction-tuned language model (e.g., instruction-tuned Gemma2 model) running on KServe or any other API that provides OpenAI-compatible interface (`v1/completion` and `v1/chat/completion` endpoints)
- A Google Kubernetes Engine (GKE) to deploy the application
- Optional: Docker installed on your local machine (if you want to build and run the application locally)
- Optional: Terraform installed on your local machine (if you want to use the automated deployment)

If you don't have a GKE cluster and a model deployed on it, you can follow the instructions provided in the [Kserve README](../kserve/README.md) to deploy your model on Google Kubernetes Engine (GKE). In that case feel free to use the same GKE cluster to deploy the chatbot application.

## Optional: Build and Run the Application Locally

You can optionally set up a local PostgreSQL instance to test the application locally.

Start by creating a network, then run the PostgreSQL container:

```bash
docker network create langchain-chatbot
docker run --rm --name postgres --network langchain-chatbot -e POSTGRES_PASSWORD=superpassword -d postgres
```

Next, build and run the application:

```bash
docker build -t langchain-chatbot app
docker run --rm --name chatbot \
   --network langchain-chatbot -p 8501:8501 \
   -e MODEL_BASE_URL=https://model.example.com/openai/v1/ \
   -e MODEL_NAME=gemma2 \
   -e DB_URI=postgresql://postgres:superpassword@postgres:5432/postgres \
   langchain-chatbot
```

## Prepare the Application for Deployment

### Create Google Container Registry (GCR)

Enable the Artifact Registry API and create a Docker repository:

```bash
gcloud services enable artifactregistry.googleapis.com
gcloud artifacts repositories create langchain-chatbot \
   --repository-format=docker \
   --location=us-central1
```

### Build the Application Using Cloud Build

Edit `cloudbuild.yaml` to reference the newly created repository, then submit the build:

```bash
gcloud builds submit app
```

### Enable IAP and create OAuth client

Before securing the application with Identity-Aware Proxy (IAP), ensure that the OAuth consent screen is configured. Go to the [IAP page](https://console.cloud.google.com/security/iap) and click "Configure consent screen" if prompted.

Next, create an OAuth 2.0 client ID by visiting the [Credentials page](https://console.cloud.google.com/apis/credentials) and selecting "Create OAuth client ID". Use the "Web application" type and proceed with the creation. Save the Client ID and secret for later use. Then go back to the [Credentials page](https://console.cloud.google.com/apis/credentials), click on the OAuth 2.0 client ID you created, and add the redirect URI as follows: `https://iap.googleapis.com/v1/oauth/clientIds/<CLIENT_ID>:handleRedirect` (replace `<CLIENT_ID>` with the actual client ID).

## Manual Deployment

This section describes how to deploy the application manually. If you prefer an automated deployment, refer to the next section.

### Create Cloud SQL Instance

On this step we will create a Cloud SQL instance and a database to store user messages. The database should be accessible from the GKE cluster where the application will be deployed. A good practice is to use a private IP address for the Cloud SQL instance. To do this, a VPC Peering connection needs to be established between the network of the GKE cluster and the Google-managed services network.

```bash
NETWORK=<your-network-name>
ADDRESS_RANGE=google-managed-services-${NETWORK}

# Create address range for VPC Peering
gcloud compute addresses create ${ADDRESS_RANGE} --network=${NETWORK} --global --purpose=VPC_PEERING --prefix-length=24

# Create a VPC Peering connection with Google-managed services network
gcloud services vpc-peerings connect --network=${NETWORK} --ranges=${ADDRESS_RANGE} --service=servicenetworking.googleapis.com
```

Once VPC Peering is established, create the Cloud SQL instance and database, and set the password for the `postgres` user:

```bash
CLOUD_SQL_INSTANCE=langchain-chatbot
DB_NAME=chat
DB_PASSWORD=superpassword

# Create Cloud SQL instance
gcloud sql instances create ${CLOUD_SQL_INSTANCE} --database-version=POSTGRES_16 --edition=ENTERPRISE --region=us-central1 --tier=db-f1-micro --network=${NETWORK} --no-assign-ip --enable-google-private-path

# Create database and set password for postgres user
gcloud sql databases create ${DB_NAME} --instance=${CLOUD_SQL_INSTANCE}
gcloud sql users set-password postgres --instance=${CLOUD_SQL_INSTANCE} --host=% --password=${DB_PASSWORD}
```

### Deploy the application to GKE

Open `deployment.yaml` and replace the placeholders with the actual values. There are three pieces of information you need to provide: model base URL, model name, and database URI. Then, create a namespace and deploy the application:

```bash
K8S_NAMESPACE=langchain-chatbot

kubectl create namespace ${K8S_NAMESPACE}
kubectl apply -n ${K8S_NAMESPACE} -f deployment.yaml
kubectl apply -n ${K8S_NAMESPACE} -f service.yaml
```

Ensure that the application is running by checking the pods:

```bash
kubectl get pods -n ${K8S_NAMESPACE}
```

At this point, the application isn't accessible from the internet yet. To interact with it, you can port-forward the service to your local machine:

```bash
kubectl port-forward -n ${K8S_NAMESPACE} svc/chat 8501:80
```

Now navigate to `http://localhost:8501` in your browser and you should see the interface of the application.

Note that as we didn't configure authentication yet, application won't save the chat history between page reloads but you can still test the chatbot functionality.

### Expose the application to the internet

To make the application accessible from the internet, we need to create an Ingress resource. The Ingress will route traffic to the application and terminate SSL connections.

First, create a static IP address for the Ingress:

```bash
gcloud compute addresses create langchain-chatbot \
  --global --ip-version=IPV4
```

Wait until the static IP address is created, then go to your domain registrar and create an A record pointing to the static IP address.

Next, update `managed-certificate.yaml` with your domain name and apply manifests for the Managed Certificate and Ingress:

```bash
kubectl apply -n ${K8S_NAMESPACE} -f managed-certificate.yaml
kubectl apply -n ${K8S_NAMESPACE} -f ingress.yaml
```

It takes some time for the Managed Certificate to be provisioned. You can check the status of the certificate using:

```bash
kubectl describe managedcertificate chat-cert -n ${K8S_NAMESPACE}
```

After certificate is provisioned, you can access the application using your domain name. But for now it is not yet secured, nor it will save the chat history between page reloads. So let's fix that.

### Configure IAP for the application

Start with creating a secret with OAuth client credentials (replace placeholders with your actual values obtained from the OAuth client creation):

```bash
kubectl create secret generic chat-ui-oauth \
  --namespace ${K8S_NAMESPACE} \
  --from-literal=client_id=<your-oauth-client-id> \
  --from-literal=client_secret=<your-oauth-client-secret>
```

Then, create a BackendConfig resource to configure IAP and update the Service resource to use the BackendConfig:

```bash
kubectl apply -n ${K8S_NAMESPACE} -f backendconfig.yaml
kubectl annotate service chat -n ${K8S_NAMESPACE} beta.cloud.google.com/backend-config=chat-ui
```

Finally, go to the IAP page in the GCP Console and add enable IAP for the application. Doint that, don't forget to add some principals (users, domains, etc.) to the allowlist.

Now, go to your domain again. You should be prompted to log in with your Google account to access the chatbot. Once logged in, you can start chatting with the chatbot. The chat history will persist between page reloads now as it's bound to your identity.

## Automated Deployment

Instead of manually following the steps above, you can use Terraform to automate the deployment of the application.

Go to the `terraform` directory, make a copy of `terraform.tfvars.example` and adjust the variables for the Terraform configuration. The minimum required variables are:

- `project_id` - your GCP project ID
- `model_base_url` and `model_name` - where to find the model
- `db_network` - the network from which the Cloud SQL instance will be accessible; it should be the same network as the GKE cluster
- `k8s_namespace` - existing namespace in your GKE cluster where the application will be deployed
- `k8s_app_image` - the name and tag of the Docker image built previously
- `support_email`, `oauth_client_id`, `oauth_client_secret` and `members_allowlist` - for IAP configuration

Make sure you have configured `google` and `kubernetes` providers either by setting the environment variables or using the `provider` blocks in the configuration.

Initialize and apply the Terraform configuration to set up the necessary infrastructure.

```bash
terraform init
terraform apply -var-file=terraform.tfvars
```

It will do the following:

- Create a PostgreSQL instance along with a database
- Connect the PostgreSQL instance to the network you specified using VPC Peering
- Create Deployment and Service resources for the application in the specified namespace of your GKE cluster
- Configure IAP to secure the application

When the Terraform run completes, it will output the public IP address and the URL of the application.

Make sure that IP address is associated with the domain you specified as the `domain_name` variable in the Terraform configuration. If not, go to your domain registrar and create an A record pointing to the IP address.

Finally, wait some time for the Managed Certificate to be provisioned and then you can access the application using your domain name.

## Interaction with the Chatbot

Once the application is deployed, you can interact with the chatbot by visiting the URL of the application in your browser. If you are using Terraform, the URL will be provided as an output, but in any case it technically should be `https://<you-domain>/`. You will be prompted to log in with your Google account to access the chatbot.

Once logged in, you can start chatting with the chatbot. The chatbot will use the language model you specified to generate responses to your messages. The chat history will be stored in the PostgreSQL database, and you can view it by connecting to the database using a PostgreSQL client.

The history is preserved across sessions, so you can continue the conversation where you left off. You can also clear the chat history using the appropriate button in the application.

## Conclusion

In this tutorial, we have deployed a chatbot application using LangChain and Streamlit on Google Cloud Platform. The application is secured with Identity Aware Proxy (IAP) and stores user messages in a Cloud SQL PostgreSQL database.
