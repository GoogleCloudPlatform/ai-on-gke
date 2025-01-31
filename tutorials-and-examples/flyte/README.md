# Running Flyte on GKE

## Overview

This guide will show how to install Flyte on GKE using Helm. Deployment will use Google Cloud Storage bucket and Cloud SQL PostgreSQL database.

## Before you begin

1. Ensure you have a GCP project with billing enabled and have enabled the GKE API.

   * Follow [this link](https://cloud.google.com/billing/v1/getting-started) to learn how to enable billing for your project.

   * GKE API can be enabled by running:

     `gcloud services enable container.googleapis.com`

1. Ensure you have the following tools installed on your workstation:

   * [gcloud](https://cloud.google.com/sdk/docs/install)
   * [kubectl](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl#install_kubectl)
   * [terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

## Setting up your GKE cluster with Terraform

Let's start with setting up the infrastructure using Terraform. The Terraform configuration will create an [Autopilot](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview) or [Standard](https://cloud.google.com/kubernetes-engine/docs/how-to/creating-a-regional-cluster) GKE cluster with GPU node pools (only for Standard clusters).

1. Create variables file for Terraform.

   Copy the `example_environment.tfvars` file to a new file, e.g., `your_environment.tfvars`, and fill `project_id` and `cluster_name` with your values. You can also adjust any other parameters as you need.

   ```hcl
   project_id = "flyte-project"
   cluster_name = "flyte-tutorial"
   autopilot_cluster = true  # Set to false for Standard    cluster
   ```

2. Initialize and apply the Terraform configuration.

   ```bash
   terraform init
   terraform apply -var-file=your_environment.tfvars
   ```

   After the Terraform apply finishes, you should see output similar to the following:

   ```text
   Apply complete! [...]

   Outputs:

   cloudsql_ip = "10.59.0.3"
   cloudsql_password = <sensitive>
   cloudsql_user = "flytepg"
   gke_cluster_location = "us-central1"
   gke_cluster_name = "flyte-test"
   bucket_name = "flyte-bucket"
   project_id = "flyte-project"
   service_account = "tf-gke-flyte-test-k3af@flyte-project.iam.gserviceaccount.com"
   ```

3. Get Kubernetes access.

   Run the following command to get the credentials for the GKE cluster:

   ```bash
   gcloud container clusters get-credentials $(terraform output -raw gke_cluster_name) --region $(terraform output -raw gke_cluster_location) --project $(terraform output -raw project_id)
   ```

4. Bind the Google Service Account (GSA) to the Kubernetes Service Account (KSA):

   The Flyte Helm chart will deploy a Kubernetes Service Account (KSA) named `flyte-backend-flyte-binary` in the `default` namespace. To allow this KSA to access Google Cloud resources, it needs to be bound to the Google Service Account (GSA) created by Terraform. Use the following command, replacing SERVICE_ACCOUNT with the email address of the GSA from the Terraform output (use `terraform output service_account` to get it again) and PROJECT_ID with your Google Cloud project ID:

   ```bash
   gcloud iam service-accounts add-iam-policy-binding SERVICE_ACCOUNT \
     --role roles/iam.workloadIdentityUser \
     --member "serviceAccount:PROJECT_ID.svc.id.goog[default/flyte-backend-flyte-binary]"
   ```

5. Configure Flyte Helm values.

   Open the `flyte.yaml` file and replace the placeholders with the values from the Terraform output:

   * replace `<FLYTE_IAM_SA_EMAIL>` with the service account email (4 occurrences)
   * replace `<PROJECT_NAME>` with the project ID (1 occurrence)
   * replace `<BUCKET_NAME>` with the bucket name (2 occurrences)
   * replace `<CLOUDSQL_IP>`, `<CLOUDSQL_USERNAME>`, `<CLOUDSQL_PASSWORD>` and `<CLOUDSQL_DBNAME>` with corresponding values (1 occurrence each; use `terraform output cloudsql_password` to get the password)

6. Install Flyte using Helm.

   ```bash
   helm install flyte-backend flyte-binary \
     --repo https://flyteorg.github.io/flyte \
     --namespace default \
     --values flyte.yaml
   ```

   After Helm finishes deploying the resources, wait for the pods to be in the `Running` state. Note that in the case of an Autopilot cluster, it may take significant time. You can use this command to track the progress:

   ```bash
   kubectl get pods -n default -w
   ```

## Access the Flyte Dashboard

At this point, the Flyte dashboard is not exposed to the internet. Let's access it using Kubernetes port forwarding.

1. Get the service name and port:

   ```bash
   $ kubectl get svc
   NAME                                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
   flyte-backend-flyte-binary-grpc      ClusterIP   34.118.237.187   <none>        8089/TCP   4h17m
   flyte-backend-flyte-binary-http      ClusterIP   34.118.226.45    <none>        8088/TCP   4h17m
   flyte-backend-flyte-binary-webhook   ClusterIP   34.118.237.19    <none>        443/TCP    4h17m
   kubernetes                           ClusterIP   34.118.224.1     <none>        443/TCP    5h17m
   ```

2. Use kubectl port-forward to do the actual forwarding:

   ```bash
   $ kubectl port-forward svc/flyte-backend-flyte-binary-http 8088:8088
   Forwarding from 127.0.0.1:8088 -> 8088
   Forwarding from [::1]:8088 -> 8088
   ```

3. Access <http://localhost:8088/console>
   ![alt text](./img/flyte_dashboard.png)

## Publish service to the internet

First, create a global static IP address for the Ingress:

```bash
gcloud compute addresses create flyte --global --ip-version=IPV4
```

Get details about the created IP address and note the IP address:

```bash
gcloud compute addresses describe flyte --global
```

If you have a domain you want to use, go to your domain registrar and create an A record pointing to the IP address you just created. If you don't have a domain, but you want to test this setup, you can use the `sslip.io` service. In that case, use the domain `<cloud-ip-address>.sslip.io` where `<cloud-ip-address>` is the IP address you just created. The other advantage of using `sslip.io` is that you don't have to manage DNS records nor wait for them to propagate.

Now, create a managed certificate for the domain you want to use:

```yaml
# managed-certificate.yaml
---
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: flyte-http
spec:
  domains:
    - <your-domain>
```

```bash
kubectl apply -f managed-certificate.yaml
```

In the final step, let's update the Helm values to enable the Ingress and use the IP address and certificate we created. Edit the `flyte.yaml` file and add the following:

```yaml
ingress:
  create: true
  httpAnnotations:
    kubernetes.io/ingress.global-static-ip-name: flyte
    networking.gke.io/managed-certificates: flyte-http
    kubernetes.io/ingress.class: "gce"
  grpcAnnotations:
    kubernetes.io/ingress.class: "gce-internal"
```

Then, update the Helm release:

```bash
helm upgrade flyte-backend flyteorg/flyte-binary --namespace default --values flyte.yaml
```

After some time, the certificate should be provisioned and the application should be accessible via the domain you specified. Note that the certificate provisioning may take some time. You can check the certificate status by running:

```bash
kubectl get managedcertificate flyte-http
```

When the status is `Active`, you should be able to access the Flyte dashboard via the domain you specified, the link would look like `https://<your-domain>/console`. If you get an SSL error, wait for a couple of minutes more.

At this step, you should be able to access the Flyte dashboard via the domain you specified. The only thing left is to secure the application. Flyte supports OAuth2 and OpenId Connect authentication, there is a guide on how to configure it [here](https://docs.flyte.org/en/latest/deployment/configuration/auth_setup.html). In case you don't need authentication, consider using [Identity-Aware Proxy](https://cloud.google.com/iap/docs) to limit access to the dashboard. The next section will guide you through this process.

## Limit access to the Flyte dashboard using Identity-Aware Proxy

Start by ensuring that the OAuth consent screen is configured. Go to the [IAP page](https://console.cloud.google.com/security/iap) and click "Configure consent screen" if prompted.

Next, create an OAuth 2.0 client ID by visiting the [Credentials page](https://console.cloud.google.com/apis/credentials) and selecting "Create OAuth client ID". Use the "Web application" type and proceed with the creation. Use the Client ID and secret to create a Secret in the Kubernetes cluster:

```bash
kubectl create secret generic flyte-http-oauth \
  --from-literal=client_id=<your-oauth-client-id> \
  --from-literal=client_secret=<your-oauth-client-secret>
```

Then go back to the [Credentials page](https://console.cloud.google.com/apis/credentials), click on the OAuth 2.0 client ID you created, and add the redirect URI as follows: `https://iap.googleapis.com/v1/oauth/clientIds/<CLIENT_ID>:handleRedirect` (replace `<CLIENT_ID>` with the actual client ID).

Create a BackendConfig resource that will enable IAP for the HTTP service:

```yaml
# backendconfig.yaml
---
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: flyte-http
spec:
  iap:
    enabled: true
    oauthclientCredentials:
      secretName: flyte-http-oauth
```

```bash
kubectl apply -f backendconfig.yaml
```

Next, update the Helm chart values for the HTTP Service to use the BackendConfig by adding the following to the `flyte.yaml` file:

```yaml
service:
  httpAnnotations:
    beta.cloud.google.com/backend-config: flyte-http
```

Then, update the Helm release again:

```bash
helm upgrade flyte-backend flyteorg/flyte-binary --namespace default --values flyte.yaml
```

Finally, go to the [IAP page](https://console.cloud.google.com/security/iap) in the GCP Console and enable IAP for the corresponding resource (it might have a name like `default/flyte-backend-flyte-binary-http`). After some time, the dashboard should be accessible only to authenticated users. To grant access to the dashboard, click "Add Principal" on the right panel and select the IAP-secured Web App User role.

When the changes propagate, try to access the dashboard again. You should be redirected to the Google login page, and after successful authentication, you should be able to access the Flyte dashboard again.

## Cleanup

Remove the Flyte Helm installation:

```bash
helm delete flyte-backend
```

Delete the static IP address:

```bash
gcloud compute addresses delete flyte --global
```

Go to the [Credentials page](https://console.cloud.google.com/apis/credentials) and delete the OAuth 2.0 client.

Finally, destroy the provisioned infrastructure:

```bash
terraform destroy -var-file=your_environment.tfvars
```
