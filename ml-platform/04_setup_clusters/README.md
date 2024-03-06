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
### This doc is meant for the platform admins or the group that has admin level permissions on the GKE clusters. The steps mentioned in these docs must be executed by them.

## Prerequisite
- You have successfully run through [03_configsync][configsync] module.

### Complete config synch setup

Go to Google Cloud Console, click on the navigation menu and click on Kubernetes Engine > Config. Now, click on the `PACKAGES`
tab. You will notice that the `Sync status` will show as stalled for all [root-sync][root-sync].
This is because, config sync needs to authenticate with GitHub to be able to read the manifests in the configsync repo. It expects a secret named `git-cred` in `config-menegement-system` namespace on the cluster.
This secret stores the github user and its [personal access token][personal-access-token]. The [personal access token][personal-access-token] should have the read only access so config sync can read the repo to perform the sync.

Follow these steps to create a new secret `git-cred` in `config-menegement-system` namespace:
- For the GitHub user account that you plan to use, generate a  [personal access token][personal-access-token] with read access to the configsync repo. It is recommended to use a [machine user account][machine-user-account] for this but you can use a personal user account just to try this reference architecture.
- Get IAM role `roles/gkehubeditor` to be able to use the connect gateway to access the GKE cluster. If you are the owner of the project, this step can be skipped.
- Open cloudshell and run these commands:
  ```
  gcloud config set project <PROJECT_ID>
  
  gcloud container fleet memberships get-credentials  <DEV_GKE_CLUSTER>
  
  kubectl create secret generic git-creds --namespace="config-management-system" --from-literal=username=<GIT_USER>  --from-literal=token=<TOKEN>
  
  gcloud container fleet memberships get-credentials  <STAGING_GKE_CLUSTER>
  
  kubectl create secret generic git-creds --namespace="config-management-system" --from-literal=username=<GIT_USER>  --from-literal=token=<TOKEN>
  
  gcloud container fleet memberships get-credentials  <PROD_GKE_CLUSTER>
  
  kubectl create secret generic git-creds --namespace="config-management-system" --from-literal=username=<GIT_USER>  --from-literal=token=<TOKEN>
  ```

After the `git-cred` secret has been created, you will see the `Sync status` for dev cluster will change from `stalled` to `synced` with a green tick mark against it. The `Synch status` for `staging` and `prod` clusters will change from stalled to Error. This is because the `staging` and `prod` branches of the repo has no content yet.

Create a pull request from `dev` to `staging` and merge it. After the merge, the `Sync status` of the `staging` cluster will change from `Stalled` to `Synced`. Now, create a PR from `staging` to `prod` and merge it. The `Sync status` for `prod` cluster will change from `Stalled` to `Synced`.

You just followed `GitOps` to promote changes from `dev` to higher environments. 

### Review the config synch repo
Open the configsync repo and go to `manifests/clusters`, you will see there is a cluster selector created for each cluster via yaml files.

### Install a cluster scoped software
This section describes how platform admins will use the configsync repo to manage cluster scoped software or cluster level objects. These software could be used by multiple teams in their namespaces. An example of such software is [kuberay][kuberay] that can manage ray clusters in multiple namespace.


Let's install [Kuberay][kuberay] as a cluster level software that includes CRDs and deployments. Kuberay has a component called operator that facilitates `ray` on Kubernetes. We will install Kuberay operator in default namespace. The operator will then orchestrate `ray clusters` created in different namespace by different teams in the future.
Perform the following steps:
- Clone the configsync repo and change directory. The default branch `dev` is checked out.
  ```
  git clone <CONFIG_SYNC_REPO> repo
  cd repo
  ``` 

- From the provided templates under `templates/_cluster_template`, copy kustomization.yaml to `manifests/clusters` which is synced with the GKE clusters. kustomization.yaml will become the entrypoint for the [root-sync][root-sync] in the `manifests/clusters` folder and it syncs all the files defined in kustomization.yaml with the cluster.
  ```
  cp templates/_cluster_template/kustomization.yaml manifests/clusters
  ```
      
- Copy the directory containing the manifests to install kuberay to the directory that is synced with the GKE clusters. 
  ```
  cp -r templates/_cluster_template/kuberay manifests/clusters
  ```
  Note that the directory `kuberay` is supplied as a template with this reference architecture. You can modify it based on your requirements.

- Add cluster selector files in kustomization.yaml so config sync syncs these files with the clusters. The selectors are useful when you want to apply changes on one or multiple clusters selectively.   
  ```
  cat <<EOF >>manifests/clusters/kustomization.yaml
  
  - ./gke-ml-dev-cluster.yaml
  - ./gke-ml-staging-cluster.yaml
  - ./gke-ml-prod-cluster.yaml
  - ./dev-selector.yaml
  - ./staging-selector.yaml
  - ./prod-selector.yaml
  EOF
  ```
  
- Commit the changes and push them to dev branch.
  ```
  git add .
  git commit -m "Installing Kuberay operator"
  git push
  ```

You just pushed the manifests to install kuberay operator in default namespace to the `dev` branch. Go to Google Cloud Console, click on the navigation menu and click on Kubernetes Engine > Config. Now, click on the `PACKAGES` tab. Verify that the dev cluster is in `Synced` status.

Verify in the `dev` cluster that [Kuberay operator][kuberay] has been installed successfully.
Open cloudshell and run these commands:
- gcloud config set project `<PROJECT_ID>`
- gcloud container fleet memberships get-credentials  `<DEV_GKE_CLUSTER>`
- kubectl get crd | grep ray
  - This should show result similar to the following:
  ```
    rayclusters.ray.io   2024-02-12T21:19:06Z
    rayjobs.ray.io       2024-02-12T21:19:09Z
    rayservices.ray.io   2024-02-12T21:19:12Z
  ```
- kubectl get pods
  - This should show result similar to the following:
    ```
    NAME                                READY   STATUS    RESTARTS   AGE
    kuberay-operator-56b8d98766-2nvht   1/1     Running   0          6m26s
    ```
As you can see , we have installed the CRDs and the deployment for the kuberay operator.

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
[configsync]: ../03_configsync




