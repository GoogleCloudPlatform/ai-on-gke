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
   * [helm](https://helm.sh/docs/intro/install/)

## Architecture overview

![Architecture overview](./img/architecture-overview.png)

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
   gcloud container clusters get-credentials $(terraform output -raw gke_cluster_name) \
     --region $(terraform output -raw gke_cluster_location) \
     --project $(terraform output -raw project_id)
   ```

4. Configure Flyte Helm values.

   Open the `flyte.yaml` file and replace the placeholders with the values from the Terraform output:

   * replace `<FLYTE_IAM_SA_EMAIL>` with the service account email (4 occurrences)
   * replace `<PROJECT_NAME>` with the project ID (1 occurrence)
   * replace `<BUCKET_NAME>` with the bucket name (2 occurrences)
   * replace `<CLOUDSQL_IP>`, `<CLOUDSQL_USERNAME>`, `<CLOUDSQL_PASSWORD>` and `<CLOUDSQL_DBNAME>` with corresponding values (1 occurrence each; use `terraform output cloudsql_password` to get the password)

5. Install Flyte to the GKE cluster using Helm.

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

   In case of any issues, you can check the logs of the pods using `kubectl logs <pod-name> -n default`. Then, after changing the values, you can update the Helm release using `helm upgrade` command with the same arguments as the `helm install` command.

## Access the Flyte Dashboard

At this point, the Flyte dashboard is not exposed to the internet. Let's access it using Kubernetes port forwarding.

1. List the services and find the service name for the Flyte HTTP service:

   ```bash
   $ kubectl get svc
   NAME                                 TYPE        CLUSTER-IP       PORT(S)
   flyte-backend-flyte-binary-grpc      ClusterIP   34.118.237.187   8089/TCP
   flyte-backend-flyte-binary-http      ClusterIP   34.118.226.45    8088/TCP
   flyte-backend-flyte-binary-webhook   ClusterIP   34.118.237.19    443/TCP
   ```

2. Use `kubectl port-forward` command to forward the Flyte HTTP service to your local machine:

   ```bash
   $ kubectl port-forward svc/flyte-backend-flyte-binary-http 8088:8088
   Forwarding from 127.0.0.1:8088 -> 8088
   Forwarding from [::1]:8088 -> 8088
   ```

   We recommend running this command in a separate terminal window or tab.

3. Open <http://localhost:8088/console> in your browser to access the Flyte dashboard.
   You should see the following screen:
   ![alt text](./img/flyte_dashboard.png)

   If you experience issues accessing the dashboard, make sure the pods are running and the port forwarding is set up correctly.

## Install Flyte CLI and run a sample workflow

1. First, create a virtual environment. The following commands will create a virtual environment in the `venv` directory and activate it:

   ```bash
   python3 -m virtualenv venv
   source venv/bin/activate
   ```

2. Install Flytekit using pip:

   ```bash
   pip install flytekit
   ```

3. Install flytectl.
   Go to the [releases page](https://github.com/flyteorg/flyte/releases), find the latest release for the `flytectl` binary, and download the one for your operating system. Unpack the archive, move the binary to a directory in your PATH, and make it executable. The actual commands may vary depending on the operating system and the version of the binary.

   For example, on Linux x86_64:

   ```bash
   curl -L -o /tmp/flytectl.tar.gz https://github.com/flyteorg/flyte/releases/download/${VERSION}/flytectl_Linux_x86_64.tar.gz
   tar -xvf /tmp/flytectl.tar.gz
   sudo install flytectl /usr/local/bin/flytectl
   ```

   In the above commands, replace `${VERSION}` with the actual release tag.

4. Start port forwarding for the Flyte GRPC service:

   ```bash
   kubectl port-forward svc/flyte-backend-flyte-binary-grpc 8089:8089
   ```

   We recommend running this command in a separate terminal window or tab.

5. Configure Flyte CLI to use backend running on the GKE cluster through port forwarding:

   ```bash
   flytectl config init --insecure --host localhost:8089
   ```

   If you get a connection error, make sure the port forwarding is set up correctly.

   If you see the message `Init flytectl config file at ...`, the configuration was successful.

6. Initialize a new Flyte project using the hello-world template:

   ```bash
   pyflyte init --template hello-world hello-world
   cd hello-world
   ```

7. Run the sample workflow in the Flyte cluster:

   ```bash
   pyflyte run --remote example.py hello_world_wf
   ```

   By default it runs the workflow in the `flytesnacks` project, in the `development` domain. You can change the project and domain using the `--project` and `--domain` flags.

8. Now Flyte will run the workflow on the GKE cluster. You can check the status of the workflow in the Flyte dashboard (ensure that port forwarding for the HTTP service is still active).
   You can also check the status using the `flytectl` CLI:

   ```bash
   flytectl get execution -p flytesnacks -d development
   ```

   Note the execution ID and wait for the execution to complete. If it fails, check the logs of the pod running the workflow:

   ```bash
   kubectl get pods -n flytesnacks-development
   kubectl logs -n flytesnacks-development <pod-name>
   ```

   In the second command above, replace `<pod-name>` with the actual name of the pod obtained from the first command.

9. To view the details of the workflow execution, including inputs and outputs, run:

   ```bash
   flytectl get execution -p flytesnacks -d development --details <execution-id>
   ```

   Replace `<execution-id>` with the actual execution ID.

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
helm upgrade flyte-backend flyte-binary \
  --repo https://flyteorg.github.io/flyte \
  --namespace default \
  --values flyte.yaml
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
