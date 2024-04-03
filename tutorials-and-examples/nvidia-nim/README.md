# Deploy NIM in GKE on NFS based Triton model-store
# dfisk@nvidia.com 4/3/2024; created
# refs:
# https://developer.nvidia.com/docs/nemo-microservices/inference/overview.html
# https://github.com/NVIDIA/TensorRT-LLM
# https://github.com/NVIDIA/TensorRT-LLM/tree/main/examples/mixtral
# https://github.com/NVIDIA/TensorRT-LLM/tree/main/examples/mixtral
# https://catalog.ngc.nvidia.com/orgs/nvidia/containers/nemo
# https://registry.ngc.nvidia.com/orgs/ohlfw0olaadg/teams/ea-participants/containers/nim_llm


$ cat <<EOF > env
export CNAME=dfisk-nim-gke-test
export PROJECTID=k80-exploration
export PROJECTUSER=dfisk
## export MACH=a2-ultragpu-1g
## export GPUTYPE=nvidia-a100-80gb
## export GPUCOUNT=1
export MACH=g2-standard-48
export GPUTYPE=nvidia-l4
export GPUCOUNT=4
export FWTAGS=nim-nfs-ingress,nim-nfs-egress
export ZONE=us-central1-a
export REGION=us-central1
export NFSDATA_FILESTORE_IPV4=${NFSDATA_FILESTORE_IPV4?}
#
alias k=kubectl
EOF
# --------------------

$ source ./env

$ gcloud filestore instances create nim-nfs --zone=${ZONE} --tier=BASIC_HDD --file-share=name="ms03",capacity=1TB --network=name="default"

$ gcloud filestore instances describe  nim-nfs --zone=${ZONE}

# update env file with created Filestore IPv4 address
$ export NFSDATA_FILESTORE_IPV4=10.237.234.194

$ gcloud compute --project=${PROJECTID?}  firewall-rules create nim-nfs-ingress \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=all \
  --source-ranges=${NFSDATA_FILESTORE_IPV4?}/32 \
  --target-tags=nim-nfs-ingress

$ gcloud compute --project=${PROJECTID?}  firewall-rules create nim-nfs-egress \
  --direction=EGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=all \
  --source-ranges=${NFSDATA_FILESTORE_IPV4?}/32 \
  --target-tags=nim-nfs-egress

$ bash install_gke_gpu-operator.sh

$ helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --set nfs.server=10.237.234.194 \
    --set nfs.path=/ms03

$ k create namespace inference-ms

$ k apply -n inference-ms -f - <<EOF
 apiVersion: v1
 kind: PersistentVolumeClaim
 metadata:
   name: nim-nfs
 spec:
   accessModes:
     - ReadWriteMany
   resources:
     requests:
       storage: 1000Gi
   storageClassName: nfs-client
EOF
# -------------- end apply

$ k get pvc -A

$ k --namespace inference-ms create secret docker-registry registry-secret --docker-server=nvcr.io --docker-username='$oauthtoken' --docker-password=${NGC_CLI_API_KEY?}

$ k --namespace inference-ms create secret generic ngc-api --from-literal=NGC_CLI_API_KEY=${NGC_CLI_API_KEY?}


# We need to patch the helm chart due to various elements in the custom-values.yaml currently being ignored
#### $ helm repo add  nemo-ms https://helm.ngc.nvidia.com/nvstaging/nim/charts --username='$oauthtoken' --password=${NGC_CLI_API_KEY?}
#### $ helm repo update

$ helm fetch https://helm.ngc.nvidia.com/nvstaging/nim/charts/nemollm-inference-0.1.3-rc6.tgz --username='$oauthtoken' --password=${NGC_CLI_API_KEY?}
$ tar -xvf nemollm-inference-0.1.3-rc6.tgz

# ----------- patch helm chart
$ diff -au statefulset.yaml.orig  nemollm-inference/templates/statefulset.yaml
--- statefulset.yaml.orig       2024-04-02 12:26:56.402184471 -0700
+++ nemollm-inference/templates/statefulset.yaml        2024-04-03 11:05:56.018277618 -0700
@@ -72,7 +72,7 @@
             - name: MODEL_NAME
               value: {{ .env.MODEL_NAME | quote }}
             - name: TARFILE
-              value: {{ .env.TARFILE | default "yes" | quote }}
+              value: {{ .env.TARFILE | default "" | quote }}
             - name: NGC_EXE
               value: {{ .env.NGC_EXE | default "ngc" | quote }}
             - name: DOWNLOAD_NGC_CLI
#

$ diff -au values.yaml.orig nemollm-inference/values.yaml
--- values.yaml.orig    2024-04-02 12:29:15.457076352 -0700
+++ nemollm-inference/values.yaml       2024-04-02 12:31:33.895823249 -0700
@@ -181,19 +181,19 @@

 # persistence settings affect the /model-store volume where the model is served from
 persistence:
-  enabled: false
-  existingClaim: ""  # if using existingClaim, run only one replica or use a ReadWriteMany storage setup
+  enabled: true
+  existingClaim: "nim-nfs"  # if using existingClaim, run only one replica or use a ReadWriteMany storage setup
   # Persistent Volume Storage Class
   # If defined, storageClassName: <storageClass>
   # If set to "-", storageClassName: "", which disables dynamic provisioning.
   # If undefined (the default) or set to null, no storageClassName spec is
   #   set, choosing the default provisioner.
-  storageClass: ""
-  accessMode: ReadWriteOnce  # If using an NFS or similar setup, you can use ReadWriteMany
+  storageClass: "nfs-client"
+  accessMode: ReadWriteMany  # If using an NFS or similar setup, you can use ReadWriteMany
   stsPersistentVolumeClaimRetentionPolicy:
     whenDeleted: Retain
     whenScaled: Retain
-  size: 50Gi  # size of claim in bytes (e.g. 8Gi)
+  size: 1000Gi  # size of claim in bytes (e.g. 8Gi)
   annotations: {}

 # hostPath configures /model-store to use a local filesystem path from the nodes -- for special cases
# ------------- end patch

$ ngc registry model list --org nvstaging --team nim "nvstaging/nim/*" --column org --column team --column name --column version --format_type csv | grep Mixtral-8x7B-Instruct-v0.1

nvstaging,nim,Mixtral-8x7B-Instruct-v0.1,h100x4_fp16_24.03.1669


$ cet <<EOF > custom-values.yaml

initContainers:
  ngcInit:
    imageName: nvcr.io/nvstaging/nim/llm_nim
    imageTag: 24.02.rc4
    secretName: ngc-api
    env:
      STORE_MOUNT_PATH: /model-store
      NGC_CLI_ORG: nvstaging
      NGC_CLI_TEAM: nim
      NGC_MODEL_NAME: mixtral-8x7b-instruct-v0-1
      NGC_MODEL_VERSION: h100x4_fp16_24.03.1669
      NGC_EXE: ngc
      DOWNLOAD_NGC_CLI: "true"
      NGC_CLI_VERSION: "3.34.1"
      TARFILE: ""
      MODEL_NAME: trt_llm
      OMPI_ALLOW_RUN_AS_ROOT: 1
      OMPI_ALLOW_RUN_AS_ROOT_CONFIRM: 1


persistence:
  enabled: true
  existingClaim: "nim-nfs"
  storageClass: "nfs-client"
  accessMode: ReadWriteMany  # If using an NFS or similar setup, you can use ReadWriteMany
  size: 1000Gi  # size of claim in bytes (e.g. 8Gi)
  annotations:
    helm.sh/resource-policy: keep

podSecurityContext:
  runAsUser: 0
  fsGroup: 0

image:
  tag: 24.02.rc4

imagePullSecrets:
  - name: registry-secret

model:
  subPath: "mixtral-8x7b-instruct-v0-1_vh100x4_fp16_24.03.1669"
  numGpus: 4
  name: trt_llm
  logLevel: "debug"
  openai_port: 9999
  nemo_port:  9998

resources:
  limits:
    nvidia.com/gpu: 4

nodeSelector:
  nvidia.com/gpu.family: ampere

service:
  type: ClusterIP
  http_port: 8000  # exposes http interface used in healthchecks to the service
  grpc_port: 8001  # exposes the triton grpc interface
  openai_port: 9999
  nemo_port:  9998
EOF
#----------------------- end file


$ helm --namespace inference-ms install nim-gke-test nemollm-inference --version 0.1.3-rc6 -f custom-values.yaml

# delete
$ helm --namespace inference-ms delete nim-gke-test

