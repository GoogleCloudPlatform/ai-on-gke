
# Best Practices for Faster Workload Cold Start

This doc  provides best practices to help achieve faster workload cold start on Google Kubernetes Engine (GKE), and discusses factors that determine the workload startup latency.


## Introduction

The cold start problem occurs when workloads are scheduled to nodes that haven't hosted the workloads before. Since the new node has no pre-existing container images, the initial startup time for the workloads can be significantly longer. This extended startup time can lead to latency issues on the overall application performance, especially for handling traffic surge by node autoscaling.


## Best Practices

#### Use secondary boot disk to accelerate container image loading

With [secondary boot disk](https://cloud.google.com/kubernetes-engine/docs/how-to/data-container-image-preloading#:~:text=GKE%20provisions%20secondary%20boot%20disks,images%20from%20secondary%20boot%20disks.)
, you can cache container images in an additional disk attached to the GKE
nodes. This way, during the start-up of the pod, the downloading image step can
be accelerated.

To use this feature, you need to bake the container images to a disk image, you
can do this by using this tool [gke-disk-image-builder](https://github.com/GoogleCloudPlatform/ai-on-gke/tree/main/tools/gke-disk-image-builder)
.

Then you can create a node pool with secondary boot disk enabled, and use 
`nodeSelector` to make your workloads scheduled in the node pool.

#### Use Persistent Disk to accelerate model weight loading

Use a Persistent Disk can accelerate the model weight loading a lot. In GKE, a
Persistend Disk can be mount as readonly on multiple nodes. So our strategy is
baking a disk image with model weights and then create Persistent Disks for
readonly use.

The following table is about time (in seconds) of loading a Gemma 7B model,
the model's data file size is around 25GB:

|                                  | read_ahead_kb=1024 | read_ahead_kb=128(default) |
|----------------------------------|--------------------|----------------------------|
| GCSFuse, 100GB pd-balanced cache | Not tested         | 137.06888                  |
| GCSFuse(1), 1T pd-ssd cache      | 81.59027293795953  | 77.48203204700258          |
| PV, 0.5T, pd-ssd                 | 112.49156787904212 | 114.35550174105447         |
| PV, 1T pd-ssd                    | 38.00010781598394  | 84.12003243801882          |
| PV, 2T pd-ssd                    | 29.2281584230077   | 86.59166808301234          |
| NFS(2)(3), 2.5T Basic-SSD        | 29.446771587       | 115.49353002902353         |
| NFS, 1T Zonal                    | 52.83657205896452  | 212.9237892589881          |

-   (1) GCSFuse without Cache: 165.0438082399778
-   (2) read_ahead_kb was set to 16384, for 1024 read_ahead_kb,
  the time was 71.699842115
-   (3) Uses Cloud Filestore for NFS

The conclustion is using a pd-ssd with 2TB size will produce best performance.


#### Use ephemeral storage with local SSDs or larger boot disks for Node

[Provision ephemeral storage with local SSDs | Google Kubernetes Engine (GKE)](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/local-ssd). 

With this feature, you can create a node pool that uses ephemeral storage with local SSDs in an existing cluster running on GKE version **1.25.3-gke.1800 or later**. And the local SSDs will also be used by kubelet and containerd as root dirs, which can improve the latency for container runtime operations such as image pull.  

```
gcloud container node-pools create POOL_NAME \
    --cluster=CLUSTER_NAME \
    --ephemeral-storage-local-ssd count=<NUMBER_OF_DISKS> \
    --machine-type=MACHINE_TYPE
```


Nodes will mount the Kubelet and container runtime (docker or containerd) root directories on a local SSD. Then the container layer to be backed by the local SSD, with the IOPS and throughput documented on [About local SSDs](https://cloud.google.com/compute/docs/disks/local-ssd#performance), which are usually more cost-effective than [increasing the PD size](https://cloud.google.com/compute/docs/disks/performance#performance_limits), below is a brief comparison between them in us-central1, with the same cost, LocalSSD has ~3x throughput than PD, with which the image pull runs faster and reduces the workload startup latency.


<table>
  <tr>
   <td style="background-color: null">With the same cost
   </td>
   <td colspan="2" style="background-color: null">LocalSSD
   </td>
   <td colspan="2" style="background-color: null">PD Balanced
   </td>
   <td colspan="2" style="background-color: null">Throughput Comparison
   </td>
  </tr>
  <tr>
   <td style="background-color: #ffffff">$ per month
   </td>
   <td style="background-color: #ffffff">Storage space (GB)
   </td>
   <td style="background-color: #ffffff">Throughput \
(MB/s) R W
   </td>
   <td style="background-color: #ffffff">Storage space (GB)
   </td>
   <td style="background-color: null">Throughput (MB/s) R+W
   </td>
   <td style="background-color: #ffffff">LocalSSD / PD (Read)
   </td>
   <td style="background-color: #ffffff">LocalSSD / PD (Write)
   </td>
  </tr>
  <tr>
   <td style="background-color: #ffffff">$
   </td>
   <td style="background-color: #ffffff">375
   </td>
   <td style="background-color: #ffffff"><strong>660   350</strong>
   </td>
   <td style="background-color: #ffffff">300
   </td>
   <td style="background-color: #ffffff"><strong>140</strong>
   </td>
   <td style="background-color: #ffffff">471%
   </td>
   <td style="background-color: #ffffff">250%
   </td>
  </tr>
  <tr>
   <td style="background-color: #ffffff">$$
   </td>
   <td style="background-color: #ffffff">750
   </td>
   <td style="background-color: #ffffff"><strong>1320 700</strong>
   </td>
   <td style="background-color: #ffffff">600
   </td>
   <td style="background-color: #ffffff"><strong>168</strong>
   </td>
   <td style="background-color: #ffffff">786%
   </td>
   <td style="background-color: #ffffff">417%
   </td>
  </tr>
  <tr>
   <td style="background-color: #ffffff">$$$
   </td>
   <td style="background-color: #ffffff">1125
   </td>
   <td style="background-color: #ffffff"><strong>1980 1050</strong>
   </td>
   <td style="background-color: #ffffff">900
   </td>
   <td style="background-color: #ffffff"><strong>252</strong>
   </td>
   <td style="background-color: #ffffff">786%
   </td>
   <td style="background-color: #ffffff">417%
   </td>
  </tr>
  <tr>
   <td style="background-color: #ffffff">$$$$
   </td>
   <td style="background-color: #ffffff">1500
   </td>
   <td style="background-color: #ffffff"><strong>2650 1400</strong>
   </td>
   <td style="background-color: #ffffff">1200
   </td>
   <td style="background-color: #ffffff"><strong>336</strong>
   </td>
   <td style="background-color: #ffffff">789%
   </td>
   <td style="background-color: #ffffff">417%
   </td>
  </tr>
</table>



#### Enable container image streaming

[Use Image streaming to pull container images | Google Kubernetes Engine (GKE)](https://cloud.google.com/kubernetes-engine/docs/how-to/image-streaming)

When customers are using Artifact Registry for their containers and meet [requirements](https://cloud.google.com/kubernetes-engine/docs/how-to/image-streaming#requirements), they can enable image streaming on the cluster by 


```
gcloud container clusters create CLUSTER_NAME \
    --zone=COMPUTE_ZONE \
    --image-type="COS_CONTAINERD" \
    --enable-image-streaming
```


Customers can benefit from image streaming to allow workloads to start without waiting for the entire image to be downloaded, which leads to significant improvements in workload startup time. For example, Nvidia Triton Server (5.4GB container image) end-to-end startup time (from workload creation to server up for traffic) can be reduced from 191s to 30s.


#### Use Zstandard compressed container images

Zstandard compression is a feature supported in ContainerD. Please note that 



1. Use the zstd builder in docker buildx

```
docker buildx create --name zstd-builder --driver docker-container \
  --driver-opt image=moby/buildkit:v0.10.3
docker buildx use zstd-builder
```


2. Build and push an image

```
IMAGE_URI=us-central1-docker.pkg.dev/<YOUR-CONTAINER-REPO>/example
IMAGE_TAG=v1

<Create your Dockerfile>

docker buildx build --file Dockerfile --output type=image,name=$IMAGE_URI:$IMAGE_TAG,oci-mediatypes=true,compression=zstd,compression-level=3,force-compression=true,push=true .
```



Now you can use `IMAGE_URI `for your workload which will have zstd compression image format. And [Zstandard benchmark](https://engineering.fb.com/2016/08/31/core-data/smaller-and-faster-data-compression-with-zstandard/) shows zstd is >3x faster decompression than gzip (the current default).


#### Use a preloader DaemonSet to preload the base container on nodes

ContainerD reuse the image layers across different containers if they share the same base container. And the preloader DaemonSet can start running even before the GPU driver is installed (driver installation takes ~30 seconds). So it can preload required containers before the GPU workload can be scheduled to the GPU node and start image pulling ahead of time.

Below is an example of the preloader DaemonSet.


```
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: container-preloader
  labels:
    k8s-app: container-preloader
spec:
  selector:
    matchLabels:
      k8s-app: container-preloader
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        name: container-preloader
        k8s-app: container-preloader
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: cloud.google.com/gke-accelerator
                operator: Exists
      tolerations:
      - operator: "Exists"
      containers:
      - image: "<CONTAINER_TO_BE_PRELOADED>"
        name: container-preloader
        command: [ "sleep", "inf" ]

```



#### Use GCS Fuse to access DataSet via file system interface

[Cloud Storage FUSE and CSI driver now available for GKE | Google Cloud Blog](https://cloud.google.com/blog/products/containers-kubernetes/announcing-cloud-storage-fuse-and-gke-csi-driver-for-aiml-workloads) enables workloads to on-demand access GCS data with a local filesystem API.


#### Use VolumeSnapshot to quickly replicating data to pods by PVC with disk image 

[Using volume snapshots | Google Kubernetes Engine (GKE)](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/volume-snapshots#create-snapshotclass) with Disk image [parameters](https://github.com/kubernetes-sigs/gcp-compute-persistent-disk-csi-driver/blob/ec41c54ffaafe4db2793d02f079e4153ac3b2ac0/pkg/common/parameters.go#L38) to provision volumes used by Pods. This is because the disk image's base storage is reused by all disks created from it in the location, so new disk creation can be done much faster.
