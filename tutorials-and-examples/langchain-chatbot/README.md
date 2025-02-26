# Deploying a Persistent Chatbot on Google Cloud Platform with LangChain, Streamlit, and IAP

- [Introduction](#introduction)
  - [Architecture overview](#architecture-overview)
  - [What is LangChain](#what-is-langchain)
  - [What is Streamlit](#what-is-streamlit)
  - [What is Identity Aware Proxy (IAP)](#what-is-identity-aware-proxy-iap)
- [Prerequisites](#prerequisites)
- [Optional: Build and Run the Application Locally](#optional-build-and-run-the-application-locally)
- [Provision GKE Cluster](#provision-gke-cluster)
- [Prepare the Application for Deployment](#prepare-the-application-for-deployment)
  - [1. Create Google Artifact Registry](#1-create-google-artifact-registry)
  - [2. Build the Application Using Cloud Build](#2-build-the-application-using-cloud-build)
  - [3. Enable IAP and create OAuth client](#3-enable-iap-and-create-oauth-client)
- [Manual Deployment](#manual-deployment)
  - [1. Create Cloud SQL Instance](#1-create-cloud-sql-instance)
  - [2. Deploy the application to GKE](#2-deploy-the-application-to-gke)
  - [3. Expose the application to the internet](#3-expose-the-application-to-the-internet)
  - [4. Configure IAP for the application](#4-configure-iap-for-the-application)
- [Automated Deployment](#automated-deployment)
- [Interaction with the Chatbot](#interaction-with-the-chatbot)
  - [Basic Troubleshooting and Debugging Tips](#basic-troubleshooting-and-debugging-tips)
  - [Common Errors and Resolutions](#common-errors-and-resolutions)
- [Conclusion](#conclusion)

## Introduction

In this tutorial, you will learn how to deploy a chatbot application using [LangChain](https://python.langchain.com/) and [Streamlit](https://streamlit.io/) on Google Cloud Platform (GCP).

Creating accessible, reliable, and secure applications is crucial for making AI models valuable for end-users. We achieve this by leveraging LangChain, Streamlit, Google Kubernetes Engine, and Cloud SQL for PostgreSQL. LangChain simplifies the integration of language models, allowing us to build robust AI-powered applications. Streamlit provides an intuitive and interactive user interface, making it easy for users to interact with the chatbot. GKE offers a scalable and managed environment to deploy the application, ensuring high availability and performance. Cloud SQL for PostgreSQL provides a reliable and secure database solution to store user messages, ensuring data persistence and consistency across sessions.

The chatbot application can be used to interact with any language model served on an OpenAI-compatible API. For example, you can use the Gemma2 model deployed on Google Kubernetes Engine using [Kserve](https://kserve.github.io/website/). This means you're not locked into a single provider and have the flexibility to choose the best model for your needs.

The application will be deployed on GCP and secured with Identity Aware Proxy (IAP). You have the option to follow manual deployment instructions or use Terraform for an automated setup.

Finally, the application will use user identity provided by IAP and store each user's messages in a Cloud SQL PostgreSQL database.

### Architecture overview

![Architecture](infrastructure-diagram.png)

### What is LangChain

LangChain is a framework designed to simplify the integration of language models into applications. It provides tools and abstractions to manage the complexities of working with language models, making it easier to build, deploy and maintain AI-powered applications.

### What is Streamlit

Streamlit is an open-source app framework used to create interactive web applications for machine learning and data science projects. It allows developers to build and deploy powerful data-driven applications with minimal effort.

### What is Identity Aware Proxy (IAP)

[Identity Aware Proxy (IAP)](https://cloud.google.com/iap) is a Google Cloud service that provides secure access to applications running on GCP. It allows you to control access to your applications based on user identity, ensuring that only authorized users can access your resources.

## Prerequisites

This tutorial assumes you have the following:

- A [Google Cloud Platform](https://cloud.google.com/) account and project
- The [Google Cloud CLI](https://cloud.google.com/sdk/docs/install-sdk) (gcloud) installed and configured
- The [Kubernetes command-line tool](https://kubernetes.io/docs/tasks/tools/#kubectl) (kubectl) installed and configured
- An instruction-tuned language model running on KServe or any other API that provides OpenAI-compatible interface (`v1/completion` and `v1/chat/completion` endpoints)
  - You can follow the instructions in the [Kserve README](../kserve/README.md) to deploy the model on Google Kubernetes Engine (we recommend using the instruction tuned Gemma2 model)
- A Google Kubernetes Engine (GKE) cluster to host the application
  - Tested on an Autopilot cluster, but any type of cluster can be used
  - This can be the same cluster that the language model is deployed on
- Optional: Docker installed on your local machine (if you want to build and run the application locally)
- Optional: Terraform installed on your local machine (if you want to use the automated deployment)

## Optional: Build and Run the Application Locally

Running the application locally allows you to quickly preview the application and catch possible configuration issues, such as incorrect model base URI, before deploying the application to the cloud.

However, running the application locally requires Docker to be installed on your machine. If you don't have Docker installed, but want to proceed with the local build and run, you can follow the instructions on the [Docker website](https://docs.docker.com/get-docker/).

Start by creating a network, then run the PostgreSQL container:

```bash
docker network create langchain-chatbot
docker run --rm --name postgres --network langchain-chatbot -e POSTGRES_PASSWORD=superpassword -d postgres
```

Next, ensure you have a language model endpoint running. If you have deployed the model using KServe on GKE, you can port-forward the model service to your local machine:

```bash
kubectl port-forward -n <model-namespace> svc/<model-service-name> 8000:80
```

Replace `<model-namespace>` and `<model-service-name>` with the appropriate values. This will make the model accessible at `http://localhost:8000`.

Now, from within the ai-on-gke/tutorials-and-examples/langchain-chatbot directory, build and run the application:

```bash
docker build -t langchain-chatbot app
docker run --rm --name chatbot \
   --network langchain-chatbot -p 8501:8501 \
   --add-host=host.docker.internal:$(hostname -I | awk '{print $1}') \
   -e MODEL_BASE_URL=http://host.docker.internal:8000/openai/v1/ \
   -e MODEL_NAME=gemma2 \
   -e DB_URI=postgresql://postgres:superpassword@postgres:5432/postgres \
   langchain-chatbot
```

Navigate to `http://localhost:8501` in your browser to access the chatbot UI. You can start chatting with the chatbot, and the chat history will be stored in the local PostgreSQL database.

If you're getting a 404 error in a chat box, it means the model is not accessible at the specified URL. Make sure the model is running and accessible at the correct URL.

## Provision GKE Cluster

This section describes how to create an [autopilot GKE cluster](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview) using the Google Cloud CLI. An autopilot cluster is a fully managed Kubernetes cluster that automatically adjusts the resources based on the workload requirements. It is a good choice for running any type of workload as it provides a balance between cost and performance.

If you already have a GKE cluster that you want to use to host the chatbot application, you can skip this section and proceed to [Prepare the Application for Deployment](#prepare-the-application-for-deployment). If you previously followed the [Kserve README](../kserve/README.md) to deploy the model, you can use the same GKE cluster to deploy the chatbot application, and you don't need to create a new cluster, so you can skip this section as well.

The command below creates an autopilot GKE cluster named `langchain-chatbot-demo` in the `us-central1` region. You can adjust the region and cluster name as needed.

```bash
gcloud container clusters create-auto langchain-chatbot-demo \
  --location=us-central1
```

After the cluster is created, you need to configure `kubectl` to connect to the cluster:

```bash
gcloud container clusters get-credentials langchain-chatbot-demo \
  --region us-central1
```

This will set up the necessary credentials and configuration for kubectl to interact with your new GKE cluster.

## Prepare the Application for Deployment

### 1. Create Google Artifact Registry

Enable the Artifact Registry API and create a Docker repository:

```bash
gcloud services enable artifactregistry.googleapis.com
gcloud artifacts repositories create langchain-chatbot \
   --repository-format=docker \
   --location=us-central1
```

### 2. Build the Application Using Cloud Build

Use the `cloudbuild.yaml` file to build and push the application image to the "langchain-chatbot" artifact registry repository created in the last step. From within the ai-on-gke/tutorials-and-examples/langchain-chatbot directory run:

```bash
gcloud builds submit app --substitutions=_REPO_NAME="langchain-chatbot"
```

### 3. Enable IAP and create OAuth client

Before securing the application with Identity-Aware Proxy (IAP), ensure that the OAuth consent screen is configured. Go to the [IAP page](https://console.cloud.google.com/security/iap) and click "Configure consent screen" if prompted.

Next, create an OAuth 2.0 client ID by visiting the [Credentials page](https://console.cloud.google.com/apis/credentials) and selecting "Create OAuth client ID". Use the "Web application" type and proceed with the creation. Save the Client ID and secret for later use. Then go back to the [Credentials page](https://console.cloud.google.com/apis/credentials), click on the OAuth 2.0 client ID you created, and add the redirect URI as follows: `https://iap.googleapis.com/v1/oauth/clientIds/<CLIENT_ID>:handleRedirect` (replace `<CLIENT_ID>` with the actual client ID). This is crucial because the redirect URI is used by the OAuth 2.0 authorization server to return the authorization code to your application. If it is not configured correctly, the authorization process will fail, and users will not be able to log in to the application.

## Manual Deployment

This section describes how to deploy the application manually. If you prefer an automated deployment, refer to the next section on Terraform [automated deployment](#automated-deployment).

### 1. Create Cloud SQL Instance

In this step, we will create a Cloud SQL instance and a database to store user messages. The database should be accessible from the GKE cluster where the application will be deployed. We will use a private IP address for the Cloud SQL instance to ensure secure communication. To do this, a VPC Peering connection needs to be established between the network of the GKE cluster and the Google-managed services network. The other option is to use a [Cloud SQL proxy](https://cloud.google.com/sql/docs/postgres/connect-auth-proxy), but it's not covered in this tutorial.

First, create an address range for VPC Peering in the GKE cluster network. If you created the GKE cluster using the instructions above, the network name is `default`. Replace `<your-network-name>` with the actual network name:

```bash
NETWORK=<your-network-name>
ADDRESS_RANGE=google-managed-services-${NETWORK}

gcloud compute addresses create ${ADDRESS_RANGE} \
  --network=${NETWORK} \
  --global \
  --purpose=VPC_PEERING \
  --prefix-length=24
```

Then, create a VPC Peering connection with the Google-managed services network:

```bash
gcloud services vpc-peerings connect \
  --network=${NETWORK} \
  --ranges=${ADDRESS_RANGE} \
  --service=servicenetworking.googleapis.com
```

Once VPC Peering is established, create the Cloud SQL instance with a private IP address; it may take about 10 minutes to create the instance. When it's ready, create a database and set the password for the `postgres` user:

```bash
CLOUD_SQL_INSTANCE=langchain-chatbot
DB_NAME=chat
DB_PASSWORD=superpassword

gcloud sql instances create ${CLOUD_SQL_INSTANCE} \
  --database-version=POSTGRES_16 \
  --edition=ENTERPRISE \
  --region=us-central1 \
  --tier=db-f1-micro \
  --network=${NETWORK} \
  --no-assign-ip \
  --enable-google-private-path

gcloud sql databases create ${DB_NAME} --instance=${CLOUD_SQL_INSTANCE}
gcloud sql users set-password postgres --instance=${CLOUD_SQL_INSTANCE} --host=% --password=${DB_PASSWORD}
```

### 2. Deploy the application to GKE

Open `deployment.yaml` and replace the placeholders with the actual values. There are three pieces of information you need to provide: model base URL, model name, and database URI.

The model base URL should point to the OpenAI-compatible API serving the language model (if you followed the instructions from the [Kserve README](../kserve/README.md), the model base URL will be something like `http://huggingface-gemma2.kserve-test.33.44.55.66.sslip.io/openai/v1` if the model is running on a separate GKE cluster, or `http://huggingface-gemma2.kserve-test.svc.cluster.local/openai/v1` in case of the model running in the same GKE cluster). The model name should match the name of the model on the API.

The database URI should follow the scheme `postgres://<username>:<password>@<host>:<port>/<database>`. The `host` can be obtained from the Cloud SQL instance details: `gcloud sql instances describe langchain-chatbot --format='value(ipAddresses[0].ipAddress)'`, the `port` is `5432`, the `username` is `postgres`, and the `database` is the name of the database you created (it's `chat` if you stick to the instructions above).

It is recommended to use environment variables to store sensitive information such as database credentials. For example:

```yaml
env:
  - name: MODEL_BASE_URL
    value: "http://<model-base-url>"
  - name: MODEL_NAME
    value: "<model-name>"
  - name: DB_URI
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: uri
```

Then, create a namespace and deploy the application:

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

Note that as we didn't configure authentication yet, the application won't save the chat history between page reloads but you can still test the chatbot functionality.

### 3. Expose the application to the internet

To make the application accessible from the internet, we need to create an Ingress resource. It manages external access to the services in a Kubernetes cluster, provides load balancing, TLS termination and name-based virtual hosting.

First, create a static IPV4 address for the Ingress:

```bash
gcloud compute addresses create langchain-chatbot \
  --global --ip-version=IPV4
```

Wait until it's provisioned. You can check the status using:

```bash
gcloud compute addresses describe langchain-chatbot --global
```

When it's ready, you will see the IP address value in the output:

```text
address: <ip-address-goes-here>
addressType: EXTERNAL
<...>
ipVersion: IPV4
kind: compute#address
<...>
name: langchain-chatbot
<...>
```

Now you need a domain name that points to this IP address. We need it to provision a Managed Certificate to secure the communication between the client and the server using HTTPS. You can use any domain name you own or use a service like `sslip.io` for testing purposes.

- In the case of a real domain, you need to create an A record pointing to the static IP address you just created; go to your domain registrar, create the record, and wait for the DNS change to propagate. This can take anywhere from a few minutes to several hours, depending on your DNS provider.
- In case of `sslip.io`, use the domain `<address>.sslip.io` using the gcloud compute address from the previous step. You don't have to manage DNS records nor wait for them to propagate in this case, so it's a good option for a quick test.

Next, update `managed-certificate.yaml` with your domain name and apply manifests for the Managed Certificate and Ingress:

```bash
kubectl apply -n ${K8S_NAMESPACE} -f managed-certificate.yaml
kubectl apply -n ${K8S_NAMESPACE} -f ingress.yaml
```

It takes some time for the Managed Certificate to be provisioned. You can check the status of the certificate using:

```bash
kubectl describe managedcertificate chat-ui -n ${K8S_NAMESPACE}
```

After the certificate is provisioned, you can access the application using your domain name. But for now, it is not yet secured, nor will it save the chat history between page reloads. So let's fix that.

### 4. Configure IAP for the application

Start with creating a secret with OAuth client credentials (replace placeholders with your actual values obtained from the OAuth client creation):

```bash
kubectl create secret generic chat-ui-oauth \
  --namespace ${K8S_NAMESPACE} \
  --from-literal=client_id=<your-oauth-client-id> \
  --from-literal=client_secret=<your-oauth-client-secret>
```

Then, create a BackendConfig resource to configure IAP and update the Service resource to use the BackendConfig:

```bash
kubectl apply -n ${K8S_NAMESPACE} -f backend-config.yaml
kubectl annotate service chat -n ${K8S_NAMESPACE} beta.cloud.google.com/backend-config=chat-ui
```

Finally, go to the IAP page in the GCP Console and enable IAP for the application. When enabling IAP, you need to specify which principals (users, groups, or domains) should be allowed or denied access. Common roles to consider include:

- **Individual Users**: Add specific email addresses of users who should have access.
- **Groups**: If you have a Google Group containing users who need access, add the group's email address.
- **Domains**: If you want to allow all users from a specific domain (e.g., your organization), add the domain.

Now, go to your domain again. You should be prompted to log in with your Google account to access the chatbot. Once logged in, you can start chatting with the chatbot. The chat history will persist between page reloads now as it's bound to your identity.

## Automated Deployment

Instead of manually following the steps above, you can use Terraform to automate the deployment of the application.

Go to the `terraform` directory, make a copy of `terraform.tfvars.example`, name the copy `terraform.tfvars`, and adjust the variables for the Terraform configuration. The minimum required variables are:

- `project_id` - your GCP project ID
- `model_base_url` and `model_name` - where to find the model; if you followed the instructions from the [Kserve README](../kserve/README.md), the `model_base_url` will be something like `http://huggingface-gemma2.kserve-test.33.44.55.66.sslip.io/openai/v1` if the model is running on a separate GKE cluster, or `http://huggingface-gemma2.kserve-test.svc.cluster.local/openai/v1` in case of the model running in the same GKE cluster
- `db_network` - the network from which the Cloud SQL instance will be accessible; it should be the same network as the GKE cluster
- `k8s_namespace` - existing namespace in your GKE cluster where the application will be deployed
- `k8s_app_image` - the full name of the Docker image in the Artifact Registry (e.g., `us-central1-docker.pkg.dev/my-project/langchain-chatbot/app:latest`)
- `support_email`, `oauth_client_id`, `oauth_client_secret` and `members_allowlist` - for IAP configuration

Additionally, you can specify the `domain` variable, which is the domain name for the ingress resource and SSL certificate. The default value is `{IP_ADDRESS}.sslip.io`, which uses the `sslip.io` service to map the IP address to a domain name.

The complete list of variables and their descriptions can be found in `variables.tf`. You can adjust the values as needed.

Make sure you have configured `google` and `kubernetes` providers either by setting the environment variables or using the `provider` blocks in the `versions.tf` configuration.

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

Make sure that the IP address is associated with the domain you specified as the `domain` variable in the Terraform configuration. If you used a real domain name, go to your domain registrar and create an A record pointing to the IP address. If you used the default `{IP_ADDRESS}.sslip.io`, no additional configuration is needed.

Finally, wait some time for the Managed Certificate to be provisioned and then you can access the application using your domain name.

## Interaction with the Chatbot

Once the application is deployed, you can interact with the chatbot by visiting the URL of the application in your browser. If you are using Terraform, the URL will be provided as an output, but in any case it technically should be `https://<your-domain>/`. You will be prompted to log in with your Google account to access the chatbot.

Once logged in, you can start chatting with the chatbot. The chatbot will use the language model you specified to generate responses to your messages. The chat history will be stored in the PostgreSQL database, and you can view it by connecting to the database using a PostgreSQL client.

The history is preserved across sessions, so you can continue the conversation where you left off. You can also clear the chat history using the appropriate button in the application.

### Basic Troubleshooting and Debugging Tips

If you encounter issues while interacting with the chatbot, here are some common troubleshooting steps.

To inspect the logs of the application, use the following command:

```bash
kubectl logs -n <namespace> <pod-name>
```

Replace `<namespace>` with the namespace where the application is deployed and `<pod-name>` with the name of the pod. You can get the list of pods using:

```bash
kubectl get pods -n <namespace>
```

To check the status of the deployment and pods, use:

```bash
kubectl get deployments -n <namespace>
kubectl get pods -n <namespace>
```

Ensure that the pods are in the `Running` state. If any pod is in the `CrashLoopBackOff` or `Error` state, inspect the logs for that pod to identify the issue.

To get information about the Ingress resource, use:

```bash
kubectl describe ingress -n <namespace> <ingress-name>
```

Replace `<namespace>` with the namespace where the application is deployed and `<ingress-name>` with the name of the Ingress resource. This will provide details about the Ingress configuration and status.

### Common Errors and Resolutions

- **404 Error in Chat Box**: This means the model is not accessible at the specified URL. Ensure the model is running and accessible at the correct URL. Check the model service and port-forwarding configuration.
- **502 Bad Gateway**: This indicates an issue with the backend service. Check the logs of the application and the status of the pods.
- **IAP Authentication Issues**: Ensure that the OAuth client ID and secret are correctly configured. Verify that the IAP is enabled and the correct principals are allowed access.
- **Database Connection Issues**: Ensure that the Cloud SQL instance is running and accessible from the GKE cluster. Check the database URI and credentials.

## Conclusion

In this tutorial, we have deployed a chatbot application using LangChain and Streamlit on Google Cloud Platform. The application is secured with Identity Aware Proxy (IAP) and stores user messages in a Cloud SQL PostgreSQL database.
