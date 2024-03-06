<!--
Copyright 2024 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-->
This doc describes how you as an App team member will use the configsync repo to manage your applications scoped to your namespace.
We will demonstrate this with an example of installing `ray` in the namespace. Typically, you can install any software or deploy any application in your namespace in the same fashion.

## Prerequisite
- You have successfully run through [05_setup_teams][team-setup] module.


## Install a software(ray)

This section is meant for the app teams that have permission only on a given namespace in the GKE clusters. The steps mentioned in this section must be executed by them.

`Ray` is s an open-source unified compute framework that makes it easy to scale AI and Python workloads — from reinforcement learning to deep learning to tuning, and model serving.
It is very commonly used by Machine Learning teams. In order to run `Ray` on Kubernetes, you need `Kuberay` operator. The `kuberay` operators can manage the ray clusters installed in different namespaces. So, if there are multiple teams that need to use `ray` can install it in their own namespace while the kuberay oeprator can manage all of them.
Installing `kuberay` requires cluster level access as it creates the CRDs. We demonstrated installing `kuberay` in [cluster-setup][cluster-setup]. 
Here we will show how to install `ray` in a namespace and configure `kuebray` to manage it.

As an app team member, you will have access to `manifests/apps/``<NAMESPACE>` folder in this repo if you are using a [mono repo][mono-repo] structure. You can perform the following steps to add `ray` manifests to the folder. The [reposync][repo-sync] will sync the manifests to the namespace on the cluster and you will get `ray` installed in your namespace.  

Note: If you are using multi repo structure, you will have access to the entire git repo and you can add the manifests in the similar fashion in the required directory to install `ray`.

### Create the manifests
- Open `cloudshell` and run the following commands:
  ```
  git clone <CONFIG_SYNC_REPO> repo && cd repo

  cp -r templates/_namespace_template/app/* manifests/apps/<NAMESPACE>/
  ```

- Replace NAMSESPACE with the name of the namespace in the newly copied files.
  ```
  sed -i 's#NAMESPACE#<NAMESPACE>#g' manifests/apps/<NAMESPACE>/* 
  ```

### Review the manifests
- `kustomization.yaml` specifies which yaml files should be synced with the cluster for this namespace. It references to a helm chart to install `ray`
- `values.yaml` contains the overriding values for the kuberay helm chart.
- `fluentd_config.yaml` specifies Configmap that will be applied to the namespace.
- `serviceaccount.yaml`(optional) sepcifies the kubernetes service account. This service account can be used for [workload identity][workload-identity].

Note that these files are provided as a template with the reference architecture for installing ray cluster. You can modify these templates as needed.

### Apply the manifest:
- Go to `cloudshell` where you cloned the repo and copied the new files.
  ```
  git add .
  
  git commit -m "Installing ray in namespace <NAMESPACE>"
  
  git push
  ```

The changes are pushed to `dev` branch so `ray` is installed on `dev` GKE cluster. To apply these changes to `staging`, create a pull request from `dev` to `staging` branch and merge it. Similarly, in order to apply the changes to `prod` cluster, create a pull request from `staging` to `prod` branch and merge it.

Go to Google Cloud Console, click on the navigation menu and click on Kubernetes Engine > Config. Now, click on the `PACKAGES` tab. The [repo-sync][repo-sync] objects should show `Sync status` as `Synced` with green tick against it.

### Verify the raycluster is in ready state in the namespace.
- Open cloudshell and run these commands:
  ```
  gcloud config set project <PROJECT_ID>

  gcloud container fleet memberships get-credentials  <DEV_GKE_CLUSTER>
 
  kubectl get raycluster -n <NAMESPACE>
  ```
- This should show result similar to the following:

  ``` 
  NAME                  DESIRED WORKERS   AVAILABLE WORKERS   STATUS   AGE
  ray-cluster-kuberay                                                  4m9s
  ```

### Update kuberay operator to manage ray in your namespace

This section is meant for platform admins or the group that has admin level permissions on the GKE clusters. The steps mentioned in these docs must be executed by them.

[Kuberay][kuberay] operator manages `ray` on Kubernetes. You need to configure kuberay operator so that it manages `ray` in your namespace. `kuberay` was installed via [rootsync][root-sync] from the folder `manifests/clusters` by platform-admin so they should be performing the following step.
- Go to `cloudshell` where you cloned the repo.

- Open `manifests/clusters/kuberay/values.yaml`
- add the namespace under `watchNamespace` tag. e.g.
  ```
  watchNamespace:
    - <NAMESPACE>
  ```
- Commit and push the changes
  ```
  git add .
  
  git commit -m "Updating kuberay operator to watch the namespace <NAMESPACE>"
  
  git push
  ```
To apply these changes to `staging`, create a pull request from `dev` to `staging` branch and merge it. Similarly, in order to apply the changes to `prod` cluster, create a pull request from `staging` to `prod` branch and merge it.

[kuberay][kuberay] operator will start managing the `ray` in your namespace on all the clusters.

### Verify the ray head and worker has been started in your namespace.
- Open `cloudshell` and run these commands:
  ```
  gcloud config set project <PROJECT_ID>

  gcloud container fleet memberships get-credentials  <DEV_GKE_CLUSTER>
  ```
- Run `kubectl get raycluster -n  ``<NAMESPACE>` . This should show result similar to the following indicating the raycluster is now ready:

  ``` 
  NAME                  DESIRED WORKERS   AVAILABLE WORKERS   STATUS   AGE
  ray-cluster-kuberay   1                 1                   ready    29m

  ```

- Run `kubectl get pods -n ``<NAMESPACE>` . This should show result similar to the following:

  ```
  NAME                                           READY   STATUS    RESTARTS   AGE
  ray-cluster-kuberay-head-sp6dg                 2/2     Running   0          3m21s
  ray-cluster-kuberay-worker-workergroup-rzpjw   2/2     Running   0          3m21s
  ```

## Contributing

*   [Contributing guidelines][contributing-guidelines]
*   [Code of conduct][code-of-conduct]

<!-- LINKS: https://www.markdownguide.org/basic-syntax/#reference-style-links -->

[contributing-guidelines]: CONTRIBUTING.md
[code-of-conduct]: code-of-conduct.md
[repo-sync]: https://cloud.google.com/anthos-config-management/docs/reference/rootsync-reposync-fields
[root-sync]: https://cloud.google.com/anthos-config-management/docs/reference/rootsync-reposync-fields
[personal-access-token]: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens
[machine-user-account]: https://docs.github.com/en/get-started/learning-about-github/types-of-github-accounts
[kuberay]: https://ray-project.github.io/kuberay/
[workload-identity]: https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity
[cluster-setup]: ../04_setup_clusters/README.md
[mono-repo]: ../05_setup_teams/README.md#mono-repo-vs-multi-repos
[team-setup]: ../05_setup_teams


