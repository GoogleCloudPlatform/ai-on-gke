# GKE Disk Image Builder
**[github.com/GoogleCloudPlatform/ai-on-gke/gke-disk-image-builder](https://github.com/GoogleCloudPlatform/ai-on-gke/gke-disk-image-builder)**
is a Go module that pulls a given list of container images and creates a disk
image from the unpacked snapshots of the images. The generated disk image be
consumed by GKE at the time of node pool creation via secondary-boot-disk
feature. The goal of this module is preloading a disk image with the container
images to improve the startup latency of k8s pods on GKE nodes using the GKE
secondary-boot-disk feature.

## Usage
This is a Go module that can be used as a library as well as a CLI . Find the
examples below to understand how this tool work better.

### Preconditions
1. You must either:
    1. Be logged into a GCP project using `gcloud auth login` on the host that
    you are running the tool
    1. Pass an OAuth file, that contain the credentials to access a GCP project,
  to the tool using the `--gcp-oauth` flag (see examples below for more info).
    1. Run the tool from the Cloud Shell.
1. If a container image resides in a private registry, the tool runner must have
access to it (See examples below).
1. Compute Engine API must be enabled.
1. Verify that `$PROJECT_NUMBER-compute@developer.gserviceaccount.com` has
`storage.objects.get` permission to the provided *GCS path* for the logs. You
can run the following command to grant proper permissions for this:

      ```shell
      gcloud storage buckets add-iam-policy-binding gs://kg-sec-disk \
      --project=$PROJECT_NAME \
      --member=serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com \
      --role=roles/storage.objectViewer
      ```
1. If a disk image with the given name (via the **--image-name** flag) already
exists, the tool will error out. Please provide a new name for the image.

### Available Flags
| Flag | Required | Default | Description |
| ------- | ------- | ------- | ------- |
| *--project-name* | Yes | nil | Name of a gcp project where the script will be run |
| *--image-name* | Yes | nil | Name of the image that will be generated |
| *--zone* | Yes | nil | Zone where the resources will be used to create the image creator resources |
| *--gcs-path* | Yes | nil | GCS path prefix to dump the logs |
| *--container-image* | Yes | nil | Container image to include in the disk image. This flag can be specified multiple times |
| *--gcp-oauth* | No | nil | Path to GCP service account credential file |
| *--disk-size-gb* | No | 10 | Size of a disk that will host the unpacked images |
| *--image-pull-auth* | No | 'None' | Auth mechanism to pull the container image, valid values: [None, ServiceAccountToken]. None means that the images are publically available and no authentication is required to pull them. ServiceAccountToken means the service account oauth token will be used to pull the images. For more information refer to https://cloud.google.com/compute/docs/access/authenticate-workloads#applications |
| *--timeout* | No | '20m' | Default timout for each step. Must be set to a proper value if the image is large to acount for the pull and image creation time step. |

### Go

Run the tool by simply running it as a Go file:

```shell
go run ./cli \
    --project-name=$PROJECT_NAME \
    --image-name=$IMAGE_NAME \
    --zone=$ZONE \
    --gcs-path=gs://$GCS_PATH/ \
    --disk-size-gb=$DISK_SIZE_GB \
    --container-image=$IMAGE_NAME
```

### Cloud Build

Create a Cloud Build config file, named **cloudbuild.yaml**:

```yaml
steps:
- name: 'gcr.io/cloud-builders/git'
  args: ['clone', 'https://github.com/GoogleCloudPlatform/ai-on-gke.git']
- name: 'gcr.io/cloud-builders/go'
  env: ['GOPATH=.']
  args:
    - 'run'
    - './ai-on-gke/gke-disk-image-builder/cli'
    - --project-name={project-name}
    - --image-name={image-name}
    - --zone={zone}
    - --gcs-path=gs://{gcs-path}/
    - --disk-size-gb={disk-size-gb}
    - --container-image={image-name}
```

And then submit it:

```shell
gcloud builds submit --config cloudbuild.yaml --no-source
```

### CLI

You can compile the module and use the generated binary:

```shell
go build -o image-builder ./cli
./image-builder \
    --project-name=$PROJECT_NAME \
    --image-name=$IMAGE_NAME \
    --zone=$ZONE \
    --gcs-path=gs://$GCS_PATH/ \
    --disk-size-gb=$DISK_SIZE_GB \
    --container-image=$IMAGE_NAME
```

## Examples

Here are some examples on how to use the tool.

### Environment Variable

**Note:** Setting this environment variables are not necessary to use the tool.
This only simplify presenting the examples.

```shell
PROJECT_NAME=my-project-name
IMAGE_NAME=example-image
ZONE=us-west1-b
GCS_PATH=gke-disk-image-builder-logs
```

### Pull an image from a public registry

```shell
go run ./cli \
    --project-name=$PROJECT_NAME \
    --image-name=$IMAGE_NAME \
    --zone=$ZONE \
    --gcs-path=gs://$GCS_PATH/ \
    --container-image=docker.io/library/nginx:latest
```

### Pull multiple images from a public registry

All the images will be pulled, unpacked and put on the same disk image. The
generated disk image is consumable by GKE the same as a single image one.

```shell
go run ./cli \
    --project-name=$PROJECT_NAME \
    --image-name=$IMAGE_NAME \
    --zone=$ZONE \
    --gcs-path=gs://$GCS_PATH/ \
    --container-image=docker.io/library/python:latest \
    --container-image=docker.io/library/nginx:latest
```

### Pull a large image from a public registry

Use the **--disk-size-gb** flag to create a larger disk as follows. This value
will be the size of output disk image.

```shell
go run ./cli \
    --project-name=$PROJECT_NAME \
    --image-name=$IMAGE_NAME \
    --zone=$ZONE \
    --gcs-path=gs://$GCS_PATH/ \
    --disk-size-gb=50 \
    --container-image=nvcr.io/nvidia/tritonserver:23.09-py3
```

### Pull an image from a private registry

The tool uses OAuth token of the GCE service account to authenticate to the
private registry. First, you must grant it read permission on the registry.

Use the **--image-pull-auth** flag as follows:

```shell
go run ./cli \
    --project-name=$PROJECT_NAME \
    --image-name=$IMAGE_NAME \
    --zone=$ZONE \
    --gcs-path=gs://$GCS_PATH/ \
    --image-pull-auth=ServiceAccountToken \
    --container-image=$CONTAINER_IMAGE_FROM_PRIVATE_REGISTRY
```

### Run the tool with a GCP OAuth token

By default the tool uses the OAuth credentials stored in
`~/.config/gcloud/application_default_credentials.json` (created by running the
`gcloud auth login` command automatically). If one must use another credentials,
a new GCP OAuth file must be provided via the **--gcp-oauth** flag.

**Note:** The path of the `--gcp-oauth` must be absolute.

**Note:** Run `gcloud auth application-default login` to refresh the existing
token or get a new one.

```shell
go run ./cli \
    --project-name=$PROJECT_NAME \
    --image-name=$IMAGE_NAME \
    --zone=$ZONE \
    --gcs-path=gs://$GCS_PATH/ \
    --gcp-oauth=/usr/local/google/home/username/another_credentials.json \
    --container-image=docker.io/library/nginx:latest
```
