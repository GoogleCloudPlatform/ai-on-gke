#! /bin/bash
# 8/26/2022 dfisk@nvidia.com; created
# ------------------------------------

# Synopsis: . ./env && ./install_gke_gpu-operator.sh ${CNAME:?} ${FWTAGS:?} ${PROJECTID:?} ${ZONE:?}


# Environment
export CNAME=${CNAME:?}
export FWTAGS=${FWTAGS:?}
export PROJECTID=${PROJECTID:?}
export ZONE=${ZONE:?}

cat <<EOF
export CNAME=${CNAME:?}
export FWTAGS=${FWTAGS:?}
export PROJECTID=${PROJECTID:?}
export ZONE=${ZONE:?}
export GPUTYPE=${GPUTYPE?}
export GPUCOUNT=${GPUCOUNT?}
EOF



echo sleeping 10 seconds to check parameters
sleep 10
echo proceeding

gcloud config set project ${PROJECTID:?}

gcloud container --project ${PROJECTID:?} clusters create ${CNAME:?}  --zone ${ZONE:?} \
--no-enable-basic-auth  --release-channel "regular" --machine-type "${MACH?}" \
--accelerator "type=${GPUTYPE:?},count=${GPUCOUNT}" --image-type "UBUNTU_CONTAINERD" \
--disk-type "pd-balanced" --disk-size "100" --metadata disable-legacy-endpoints=true \
--scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write",\
"https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol",\
"https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
--max-pods-per-node "110" --num-nodes "1" --logging=SYSTEM,WORKLOAD --monitoring=SYSTEM --enable-ip-alias \
--network "projects/${PROJECTID:?}/global/networks/default" \
--subnetwork "projects/${PROJECTID:?}/regions/$(echo ${ZONE:?} | cut -d- -f1)"-"$(echo ${ZONE:?} | cut -d- -f2)/subnetworks/default" \
--no-enable-intra-node-visibility --default-max-pods-per-node "110" --no-enable-master-authorized-networks \
--addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver --enable-autoupgrade --enable-autorepair \
--max-surge-upgrade 1 --max-unavailable-upgrade 0 --enable-shielded-nodes --tags ${FWTAGS:?} --node-locations ${ZONE:?}

gcloud container clusters get-credentials ${CNAME:?} --zone ${ZONE:?}

kubectl create ns gpu-operator

cat << EOF | kubectl apply -f=-
apiVersion: v1
kind: ResourceQuota
metadata:
  name: gpu-operator-quota
  namespace: gpu-operator
spec:
  hard:
    pods: 100
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values:
      - system-node-critical
      - system-cluster-critical
EOF
# ----------------- end file

helm repo add nvidia https://nvidia.github.io/gpu-operator && helm repo update

helm install gpu-operator nvidia/gpu-operator -n gpu-operator

