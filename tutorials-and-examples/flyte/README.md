# Running Flyte on GKE

## Overview

This guide will show how to install Flyte on GKE using Helm. Deployment will use Google Cloud Storage bucket and Cloud SQL PostgreSQL database.

## Before you begin

1. Ensure you have a GCP project with billing enabled and have enabled the GKE API.
   [How to enable billing](https://cloud.google.com/billing/v1/getting-started)
   And for the GKE API:

   ```bash
   gcloud services enable container.googleapis.com
   ```

2. Ensure you have the following tools installed on your workstation:

   * [gcloud CLI](https://cloud.google.com/sdk/docs/install)
   * [kubectl](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl#install_kubectl)
   * [terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

## Setting up your GKE cluster with Terraform

We’ll use Terraform to provision:

* A GKE cluster ([Autopilot](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview) or [Standard](https://cloud.google.com/kubernetes-engine/docs/how-to/creating-a-regional-cluster))
* GPU node pools (only for Standard clusters)

Create your environment configuration (.tfvars) file and edit based on example_environment.tfvars.

```hcl
project_id = "flyte-project"
cluster_name = "flyte-tutorial"
autopilot_cluster = true  # Set to false for Standard cluster
```

1. Initialize the modules:

   ```bash
   terraform init
   ```

2. Apply while referencing the `.tfvars` file we created:

   ```bash
   terraform apply -var-file=your_environment.tfvars
   ```

   And you should see your resources created:

   ```text
   Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

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
   Fetch the kubeconfig file by running:

   ```bash
   gcloud container clusters get-credentials $(terraform output -raw gke_cluster_name) --region $(terraform output -raw gke_cluster_location) --project $(terraform output -raw project_id)
   ```

4. Get the deployed service account name by running:

   ```bash
   terraform output service_account
   ```

5. Use the service account name to create an IAM policy binding to enable workload identity:

   ```bash
   gcloud iam service-accounts add-iam-policy-binding SERVICE_ACCOUNT \
     --role roles/iam.workloadIdentityUser \
     --member "serviceAccount:PROJECT_ID.svc.id.goog[default/flyte-backend-flyte-binary]"
   ```

   Where `flyte-backend-flyte-binary` is the Kubernetes service account that the Flyte Helm chart deploys by default.

6. Change all instances of `<FLYTE_IAM_SA_EMAIL>` in the included flyte.yaml Helm values file to the same service account from step 4.

   ```yaml
   inline:
     # This section automates the IAM Role annotation for the default KSA on each project namespace to enable IRSA
     # Learn more: https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html
     cluster_resources:
       customData:
       - production:
         - defaultIamServiceAccount:
             value: <FLYTE_IAM_SA_EMAIL>
       - staging:
         - defaultIamServiceAccount:
             value: <FLYTE_IAM_SA_EMAIL>
       - development:
         - defaultIamServiceAccount:
             value: <FLYTE_IAM_SA_EMAIL>
   ...
   # serviceAccount Configure Flyte ServiceAccount
   serviceAccount:
     # create Create ServiceAccount for Flyte
     create: true
     # Automates annotation of default flyte-binary KSA. Make sure to bind the KSA to the GSA: https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#authenticating_to
     annotations:
       iam.gke.io/gcp-service-account: <FLYTE_IAM_SA_EMAIL>
   ```

7. Get the Cloud SQL username and password:

   ```bash
   $ terraform output cloudsql_ip
   "10.59.0.3"
   $ terraform output cloudsql_user
   "flytepg"
   $ terraform output cloudsql_password
   "password"
   ```

   and replace the values inside the flyte.yaml values file:

   ```yaml
   configuration:
     # database Specify configuration for Flyte's database connection
     database:
       # username Name for user to connect to database as
       username: flytepg
       # password Password to connect to database with
       # If set, a Secret will be created with this value and mounted to Flyte pod
       password: "password"
       # host Hostname of database instance
       host: 10.59.0.3
       # dbname Name of database to use
       dbname: flytepg
   ```

8. Get the bucket name:

   ```bash
   $ terraform output bucket_name
   "flyte-bucket"
   ```

   and replace the values in the values file:

   ```yaml
   storage:
     # metadataContainer Bucket to store Flyte metadata
     metadataContainer: "flyte-bucket"
     # userDataContainer Bucket to store Flyte user data
     userDataContainer: "flyte-bucket"
     # provider Object store provider (Supported values: s3, gcs)
     provider: gcs
     # providerConfig Additional object store provider-specific configuration
     providerConfig:
       # gcs Provider configuration for GCS object store
       gcs:
         # project Google Cloud project in which bucket resides
         project: "flyte-project"
   ```

9. Add the Flyte Helm repo:

   ```bash
   helm repo add flyteorg https://flyteorg.github.io/flyte
   ```

10. Install Flyte using Helm and the flyte.yaml values file:

   ```bash
   helm install flyte-backend flyteorg/flyte-binary --namespace default --values flyte.yaml
   ```

   After Helm finishes deploying the resources, wait for the pods to be in the `Running` state.
   Note that in the case of an Autopilot cluster, it may take significant time. You can use this command to track the progress:

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
