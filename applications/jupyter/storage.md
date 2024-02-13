# Persistent Storage

## GCSFuse

**Important Note:** To use option, a GCS bucket must already be created within the project with the name in the format of `gcsfuse-{username}`

GCSFuse allow users to mount GCS Buckets as their local filesystem. This option allows ease of access on Cloud UI:

![Profiles Page](images/gcs_bucket.png)

Since this bucket in GCS, there is built in permission control and access outside of the clutser.

## Filestore

[Filestore CSI driver](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/filestore-csi-driver#storage-class) supports automatic creation of Filestore instances using the CSI dynamic provisioning workflow.

**Important Note:** Currently the tier used is the `standard` tier. Different other tiers may require different handling.

Filestore can be accessed by any GCE instance within the same VPC network. If using non default network for the GKE cluster, users will have to point the storage class to the correct network. [Click here for more information](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/filestore-csi-driver#storage-class)

If using a Shared VPC network, go [here](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/filestore-csi-driver#shared-vpc-access)

### Using the same PV within one namespace

The current PVC naming template is deteremined by the Jupyterhub config:

```unset
singleuser:
...
    storage:
        dynamic:
            pvcNameTemplate: claim-{username}
...
```

This means that every single users will have their own PVC+PV. For users that want to share the PV within the same namespace, they can set the `pvcNameTemplate` to a more generic/static template. **Important** Changing the `pvcNameTemplate` means that when re-mounting, the name of the PVC will also have the match this new template.

### Remounting a Filestore instance

A new Filestore instance will be created everytime the option is selected unless there is already an existing PVC under the format `claim-{USERNAME}`. This means that to reuse an existing Filestore instance will require manual remounting.

1. Open up the Filestore page in [cloud console](https://console.cloud.google.com/filestore/instances). It will look something like this:

![Filestore instance](images/filestore_instance_screenshot.png)

2. Fill out both `filestore-pv.yaml` and `filestore-pvc.yaml` under the `persistent_storage_deployments` directory. The cloud console will have the necessary information.

3. Deploy the PVC/PV into the correct namespace (PV is cluster resource so this only applies to PVC)

4. Login to Jupyterhub using the desired user and select Filestore as persistent storage.