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


### This doc is meant for the platform admins or the group that has admin level permissions on the GKE clusters. The steps mentioned in these docs must be executed by them.

## Prerequisite
- You have successfully run through [04_setup_clusters][cluster-setup] module.

## Setup teams
Typically, each team can own one or more namespaces  and the team's users will get access to create, update and delete objects in those namespaces but they will be restricted from creating, updating or deleting cluster level objects or the objects in other namespaces.

The platform admin will set up the teams(create namespace and permission team's users on it) using the configsync repo(via [root sync][root-sync]) and provide the app teams the means to manage objetcs in their own namepsace without further involvment.

Setting up a team has the following steps:
- create a new namespace for the team and permission the users on the namespace.
  
  Note: In this reference architecture, we create the namespace with the same name as the team. In real-world scenario, a team can own multiple namespaces so you might want to create namespaces with the application name that will be deployed in it.
- create a network-policy(optional). App teams can do it later.
- create a [reposync][repo-sync] object on the GKE clusters that will be associated with the repo/dir that is owned by the app teams. The app teams can manage the namespace scoped resources via their repo/dir by adding the kubernetes manifests there.

### Prepare the changes to create a team

In order to create a new namespace, perform the following steps:
- Clone the configsync repo and change directory. The default branch `dev` is checked out.
  ```
  git clone `<CONFIG_SYNC_REPO>` repo
  cd repo
  ``` 
- Copy the team template directory to the directory that is synced with the GKE clusters. The team template directory contains manifests to create namespace,[rbac][rbac],network policy and [reposync][repo-sync]
  ```
  cp -r templates/_cluster_template/team manifests/clusters/<NAMESPACE>
  ```
  `<NAMESPACE>` is the name of the team for which the namespace is being created. It can also be the name of the application.
   Note that the team template is provided with this reference architecture. You can modify it based on your requirements.



- Change the placeholders in the files under `manifests/clusters/<NAMESPACE>`
  - replace NAMSESPACE with the name of the namespace/team in the files under `manifests/clusters/<NAMESPACE>`
    ```
    sed -i 's#NAMESPACE#<NAMESPACE>#g' manifests/clusters/<NAMESPACE>/*  
    ```
  - replace GIT_REPO with the link to the Git repository that you want to sync with this reposync in `manifests/clusters/<NAMESPACE>/reposync.yaml`.
    ```
    sed -i 's#GIT_REPO#<HTTP_URL_OF_GIT_REPO>#g' manifests/clusters/<NAMESPACE>/reposync.yaml
    ```
  - manually replace NUMBER_OF_CHARACTERS_IN_REPOSYNC_NAME in `manifests/clusters/<NAMESPACE>/reposync.yaml`
    e.g if the reposync name is prod-myteam, replace NUMBER_OF_CHARACTERS_IN_REPOSYNC_NAME with 11.

- Create a new directory that the reposync object is pointing to.
  ```
  mkdir manifests/apps/<NAMESPACE>
  touch manifests/apps/<NAMESPACE>/.gitkeep
  ```
  
- Add the path to the new team dir in kustomization.yaml to include it in the sync. 
   ```
   cat <<EOF >>manifests/clusters/kustomization.yaml
   - ./<NAMESPACE>
   EOF
   ```


### Review the files:
Go to `manifests/clusters/<NAMESPACE>`
- kustomization.yaml specifies which yaml files should be synced with the cluster.
- namespace.yaml defines the code to create a new namespace.
- rbac.yaml creates a role for full access to the namespace and assign the role to the team's users.
  - This can be changed to a more restricted role or you can create multiple roles for different users.
  - There is also a rolebinding that provides [kuberay operator][kuberay] service account access to this namespace. This is required for [kuberay][kuberay] to be able to manage the ray clusters inside this namespace.
- reposync.yaml creates [reposync][repo-sync] object on the cluster for the given namespace. The [reposync][repo-sync] object will be connected to a repo and will be used by the app team to create, update and delete the namespace scoped objects like rayclusters etc. 
  - The app team either can bring their own repo and provide it to the platform admins so they can update reposync.yaml accordingly. 
  - Alternatively, if your organization wants to follow mono repo structure, platform admin can create a subfolder named `<TEAM>` in this repo for each team under `manifests/apps` and provide the path `manifests/apps/<NAMESPACE>`to the [reposync][repo-sync] object for that namespace. Platform admin can permission only the required team members to be able to edit the files under `manifests/apps/``<TEAM>` folder.
  - see the `repo`, `revision` and `dir` tags in `reposync.yaml` that defines wha repo and dir will be synced for this [reposync][repo-sync].
  - see [mono repo vs multi repos](#mono-repo-vs-multi-repos) if you want to decide which one to use.

### Apply the changes:
Commit the changes and push them to dev branch.
```
git add .
git commit -m "Adding a new team"
git push
```

The changes are pushed to `dev` branch so the namespace and related objects will be created in dev GKE cluster.
Now create pull request from `dev` to `staging` branch and merge it. Then create a pull request from `staging` to `prod` branch and merge it. This will create the namespace and related objects in `staging` and `prod` GKE clusters.

Go to Google Cloud Console, click on the navigation menu and click on Kubernetes Engine > Config. Now, click on the `PACKAGES` tab. You will see a new [repo-sync][repo-sync] object created on each cluster but they will be in `Stalled` state.
This is because config sync needs to authenticate with GitHub to be able to read the manifests in the repo. It expects a secret named `git-cred` in the namespace for configuring [reposync][repo-sync] with the GitHub repo.
This secret stores the github user and its [personal access token][personal-access-token].

Follow these steps to create a new secret in dev cluster `git-cred`:
- For the GitHub user account that you plan to use, generate a  [personal access token][personal-access-token] with read access to the configsync repo. It is recommended to use a [machine user account][machine-user-account] for this but you can use a personal user account just to try this reference architecture.
- Get IAM role roles/gkehubeditor to be able to use connect gateway to access the GKE cluster. If you are the owner of the project, this step can be skipped.
- Open cloudshell and run these commands:
  ```
  gcloud config set project <project_id>
  
  gcloud container fleet memberships get-credentials <DEV_GKE_CLUSTER>

  kubectl create secret generic git-creds --namespace="<NAMESPACE>" --from-literal=username=<GIT_USER>  --from-literal=token=<TOKEN>
    
  gcloud container fleet memberships get-credentials  <STAGING_GKE_CLUSTER>
    
  kubectl create secret generic git-creds --namespace="<NAMESPACE>" --from-literal=username=<GIT_USER> --from-literal=token=<TOKEN>
  
  gcloud container fleet memberships get-credentials  <PROD_GKE_CLUSTER>
    
  kubectl create secret generic git-creds --namespace="<NAMESPACE>" --from-literal=username=<GIT_USER> --from-literal=token=<TOKEN>
  ```


Go to Google Cloud Console, click on the navigation menu and click on Kubernetes Engine > Config. Now, click on the `PACKAGES` tab. You will see a new [repo-sync][repo-sync] object will have `Synch status` as `Synced` with a green tick mark against them. This confirms that the [reposync][repo-sync] objects have been successfully created on all the clusters.

This marks the completion of the team/namespace.


The platform admin will provide access to this dir to the members of the team. The team members will create manifests under this folder to manage their namespace scoped objects.


Important : 
Platform admins should also restrict access to this directory so only the members of the team can update the files under it.
This can be done by creating CODEOWNERS files to allow the required team members to have access to this dir. This way you will ensure that only the team members can manage Kubernetes objects in this namespace and no other team can do that. If the team members try to create cluster-scoped objects from this dir, it will result in error as this folder is connected to [reposync][repo-sync] objects which doesn't allow cluster level access.

 
### Mono repo vs multi repos
The platform admins and the app teams need to make a decision on what repo structure they will use for config sync.

Using mono repo means:
- The same repo will be used for cluster level objects(created by platform admins) and namespace level objects(created by app teams). 
- The platform admins will be the owner of the repo and maintain CODEOWNERS files to provide granular access to the platform admins and the app teams.
- However, if the app teams want to promote changes from one env to another, they will reply on platform admins or the repo owners to approve the PR.

Using multiple repos mean:
- The [rootsync][root-sync] will be tied to a repo that only platform-admins own and they can create cluster level objects from this repo.
- The [reposync][repo-sync] for individual teams will be created and tied to their own git repos. There is no need for granular permissions by platform admins as the app teams use their own repos to create namespace level objects. 
- The app teams can create and merge PRs to their own repo independently to promote changes from one env to another.


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
[rbac]: https://kubernetes.io/docs/reference/access-authn-authz/rbac/
[cluster-setup]: ../04_setup_clusters 


