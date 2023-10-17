# GCP IAP Authenticator

We combine the Jupyterhub image and our own authenticator. By default, the JupyterHub images already have pre-installed authenticator classes such as GitHub, Auth0, and Globus. In order to specify our own class for JupyterHub, our class must also live in the JupyterHub image.

## Creating Image

> **_NOTE:_** An Artifact Registry Repo for this docker image is required. Create an AR Repo following [this guide](https://cloud.google.com/artifact-registry/docs/repositories/create-repos)

1. Setup gcloud to point to your project.

2. Navigate to the `docker_image` directory. `cd docker_image`

3. Edit the `cloudbuild.yaml` file and replace the repository with your own repository.

4. Run `gcloud builds submit --config cloudbuild.yaml .` to upload it to your repository.

5. Change the hub image name and tag in the [Jupyterhub config yaml](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/jupyter-on-gke/jupyter_config/config-selfauth.yaml#L13).

## Configuration

To use the image once the it's uploaded to GCR/AR, edit the jupyterhub values `config.yaml` to use the image. Ex:

```yaml
hub:
  image: 
    name: gcr.io/aaronliang-agones-gke-dev/k8s-hub
    tag: latest
```

And set the authenticator class within the same file. Ex:

```yaml
...
    config: 
    JupyterHub:
      authenticator_class: 'gcpiapjwtauthenticator.GCPIAPAuthenticator'
...
```

This will tell Jupyterhub to use the specified authenticator class.

Pass the required fields needed by 'gcpiapjwtauthenticator.GCPIAPAuthenticator'. Ex:

```yaml
...
    GCPIAPAuthenticator: 
      header_name: 'X-Goog-IAP-JWT-Assertion'
      # This config option should match the aud field of the JSONWebToken. Required. 
      expected_audience: '/projects/1085966111635/global/backendServices/8415836356342891701'
...
```

Fortuantely, few of these steps are already done for you if you follow the Jupyter-on-gke instructions.

## IAPUserLoginHandler and GCPIAPAuthenticator class

There are two classes within `gcpiapjwtauthenticator.py`, IAPUserLoginHandler and GCPIAPAuthenticator.
IAPUserLoginHandler is the python class that only has the JWT handler. It is used by the GCPIAPAuthenticator and therefore by Jupyterhub.
GCPIAPAuthenticator contains the `get_handler()` method that Jupyterhub requires for a custom authenticator. When Jupyterhub uses the GCPIAPAuthenticator by calling `get_handler()`, it will receieve the `IAPUserLoginHandler.get()` handler method.
