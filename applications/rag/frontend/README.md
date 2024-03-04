# RAG-on-GKE Frontend Webserver

This directory contains the code for a frontend flask webserver integrating with the inference
backend and (NYI) vector database through [LangChain](https://python.langchain.com/docs/get_started/introduction).

## Cloud Run Setup

1. Configure inference internal loadbalancer service:
```
export INFERENCE_DEPLOYMENT=gemma-7b-it  # Customize as needed
kubectl create service loadbalancer $INFERENCE_DEPLOYMENT --tcp=80:8080 && \
kubectl annotate service/$INFERENCE_DEPLOYMENT "cloud.google.com/load-balancer-type=Internal"

# Record the LoadBalancer IP
kubectl get service $INFERENCE_DEPLOYMENT --watch # Wait for external endpoint to be populated, then ^C
export INFERENCE_ENDPOINT=$(kubectl get svc gemma-7b-it -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

2. Configure environment variables
```
# Change these values to match your desired Cloud Run deployment
export PROJECT_ID=my-project
export PROJECT_NUM=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
export REGION=us-central1

export INSTANCE_CONNECTION_NAME=my-project:us-central1:pgvector-instance
export DB_USER=<user name>
export DB_PASSWORD=<password>
```

3. Configure [direct VPC egress](https://cloud.google.com/run/docs/configuring/shared-vpc-direct-vpc) to connect Cloud Run to GKE.
```
gcloud projects add-iam-policy-binding $PROJECT_ID \
--member "serviceAccount:service-${PROJECT_NUM}@serverless-robot-prod.iam.gserviceaccount.com" \
--role "roles/compute.networkUser" \
--condition "None"
```

4. Deploy the frontend server to Cloud Run. The following command assumes the cluster is using the
   default network & subnetwork names.
```
gcloud beta run deploy rag-frontend \
  --network projects/${PROJECT_ID}/global/networks/default \
  --subnet projects/${PROJECT_ID}/regions/${REGION}/subnetworks/default \
  --vpc-egress=private-ranges-only \
  --region ${REGION} \
  --set-env-vars="INFERENCE_ENDPOINT=${INFERENCE_ENDPOINT}:80,INSTANCE_CONNECTION_NAME=${INSTANCE_CONNECTION_NAME},DB_USER=${DB_USER},DB_PASSWORD=${DB_PASSWORD},PROJECT_ID=projects/${PROJECT_ID}" \
  --no-allow-unauthenticated \
  --source=. \
  --memory=4Gi
```

### (Optional) Impersonate Cloud Run Service Account

1. Create the service account, and bind it to the `Cloud Run Invoker` role:
```
gcloud iam service-accounts create cloud-run-access --description="Cloud Run Access"
gcloud run services add-iam-policy-binding rag-frontend \
    --member=serviceAccount:cloud-run-access@${PROJECT_ID}.iam.gserviceaccount.com \
    --role="roles/run.invoker" --region=$REGION
```

2. Grant yourself permission to impersonate the service account:
```
export USER_EMAIL="you@gmail.com"  # Customize this
gcloud iam service-accounts add-iam-policy-binding \
    cloud-run-access@${PROJECT_ID}.iam.gserviceaccount.com \
    --member="user:$USER_EMAIL" \
    --role="roles/iam.serviceAccountUser"

# Required to mint short-lived impersonation tokens
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="user:${USER_EMAIL}" \
    --role="roles/iam.serviceAccountTokenCreator"
```

3. Grab an identity token to act as the Cloud Run Access service account
```
gcloud auth print-identity-token --impersonate-service-account=cloud-run-access@${PROJECT_ID}.iam.gserviceaccount.com | xclip -sel clip
```
Note: This token is short lived and you may need to refresh it periodically if you see auth errors.

4. Access the service by setting the `Authorization: Bearer $TOKEN` HTTP header.

In this section we'll inject an Authorization header into each of our requests to the frontend using Burp Suite.

    1. Install Burp Suite Community Edition (go/burp)
    2. Run Burp
    3. Go to the Proxy tab and click the toggle to turn "Intercepting Off" to "Intercepting On"
    4. Click on "Proxy settings"
    5. Under "Match and replace rules" add a Request header rule that sets Replace to "Authorization: Bearer <YOUR_TOKEN>"
    6. Exit Settings
    7. Click Open browser
    8. Visit your front end
    9. Click forward to step through any requests and responses

5. Enable Cloud Data Loss Prevention (DLP)

We have two ways to enable the api:

    1. Go to https://console.developers.google.com/apis/api/dlp.googleapis.com/overview click enable api.
    2. Run command: `gcloud services enable dlp.googleapis.com`

This filter can auto fetch the templates in your project. Please refer to the following links to create templates:

    1. Inspect templates: https://cloud.google.com/dlp/docs/creating-templates-inspect
    2. De-identification templates: https://cloud.google.com/dlp/docs/creating-templates-deid