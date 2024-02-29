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
## Requirements

| Name | Version |
|------|--------|
| <a name="requirement_github"></a> [github](#requirement\_github) | >= 4.3.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 4.72.1 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | >= 4.72.1 |

## Inputs

| Name                                                                                               | Description                                                                                                                 | Type     | Default | Required |
|----------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------|----------|---------|:--------:|
| <a name="input_project_id"></a> [project\_id](#input\_project\_id)                                 | Id of the GCP Project where the resources will be created. It is a map with environments as keys and project ids as values. | `map`    | n/a |   yes    |
| <a name="input_github_user"></a> [github\_user](#github\_user)                                     | GitHub user name.                                                                                                           | `string` | n/a |   yes    |
| <a name="input_github_email"></a> [github\_email](#input\_github\_email)                           | GitHub user email.                                                                                                          | `string` | n/a |   yes    |
| <a name="input_github_org"></a> [github\_org](#input\_github\_org)                                 | GitHub org.                                                                                                                 | `string` | n/a |   yes    |
| <a name="input_github_token"></a> [github\_token](#input\_github\_token)                           | GitHub access token                                                                                                         | `string` | n/a |   yes    |
| <a name="input_lookup_state_bucket"></a> [lookup\_state\_bucket](#input\_lookup\_state\_bucket)    | Lookup TF State bucket. Used for looking up resources created in steps 01 and 02.                                           | `string` | n/a |   yes    |
| <a name="input_configsync_repo_name"></a> [configsync\_repo\_name](#input\_configsync\_repo\_name) | Configsync repo name to be created in GitHub.                                                                               | `string` | n/a |    no    |

## Prerequisite
- You have created GKE clusters using [02_gke][cluster] module.
- You have the role `roles/Owner` on the projects where you have created GKE clusters.

## Usage
- Clone the repo and change dir
  ```
  git clone https://github.com/GoogleCloudPlatform/ai-on-gke
  cd ml-platform/03_configsync
  ```   
- In backend.tf replace `YOUR_STATE_BUCKET` with the name of the GCS bucket.
- In variables.tf, provide the values of the following variables:
  - `github_user`          : GitHub user. We recommend you use a system user account. 
  - `github_email`         : Email of the system user account.
  - `github_org`           : GitHub org where the config sync repo will be created.
  - `lookup_state_bucket`  : name of the GCS bucket.
  - `configsync_repo_name` : Suitable name for your config sync repo.
  
- You also need to provide a personal access token for the GitHub user. Generate a [personal access token][personal-access-token] with access to create and delete repo for the user in GitHub and pass it as env variable:
  - export TF_VAR_github_token="`<TOKEN>`"
- terraform init
- terraform plan
- terraform apply --auto-approve


This module performs the following actions:
- Looks up project_id from the state file if not provided.
- Looks up GKE clusters created in step 02.
- Creates a GitHub repository and branches corresponding to each environment and apply branch protection rules on it. This is the configsync repo.
- Creates Config sync on each GKE clusters. 
- Hydrates templates into K8s manifests and commit them to the default branch of the GitHub repo to do initial cluster setup.

## Config sync repo workflow
After this module has been successfully completed, you will get a [root-sync][root-sync] object created on all the GKE clusters. 

Go to Google Cloud Console, click on the navigation menu and click on Kubernetes Engine > Config. Now, click on the `PACKAGES` tab. You will see three [root-sync][root-sync]  objects created, one for each cluster. Review the `Source url` against the `dev` cluster. It should be something like: 
``` 
https://github.com/<GIITHUB_ORG>/experiment-acm-repo/tree/dev/manifests/clusters 

```
This means that the `dev` cluster is associated with the `manifests/clusters` folder on the `dev` branch of the configsync repo. So, manifests under `manifests/clusters` folder on the `dev` branch will be synced with the dev cluster.
Similarly, the folder `manifests/clusters` on `staging` branch will be synced with the `staging` cluster and `manifests/clusters` on `prod` branch will be sycned with `prod` cluster.

We will follow GitOps methodology to create resources on the clusters. This means you can only make changes to the default branch while other branches are protected. In order to merge changes to non-default branches, you will need to create a pull request.

The following documentation will assume that you have three clusters `dev`, `staging` and `prod` and that resulted in three branches on the configsync repo `dev`, `staging` and `prod`.  The `dev` branch is the default branch.

To follow `GitOps` approach, you will make changes and push them to the `dev` branch. Config sync will then sync the `dev` branch with the `dev` cluster. If the changes look good in `dev` environment,
and are ready to be moved to `staging` you create a pull request from `dev` to `staging` branch. Once this pull request is approved and merged, the `staging branch` will be synced with `staging` cluster reflecting the changes in staging environment. 
Similarly, when you are ready to promote the changes in production environment, create a pull request from `staging` to `prod` branch and merge it.

## Managing cluster-level and application-level objects

It is recommended to have a separation of duties on who should be able to create what objects in a cluster.
The principle to follow should be that the cluster-level objects can only be created by platform admins while the application teams should be able to create their own application level objects.

To achieve this separation, we will use [root-sync][root-sync] and [repo-sync][repo-sync]. [root-sync][root-sync] allows to creae cluster scoped objects while [repo-sync][repo-sync] allows to create namespace scoped objects.

### Cluster-level objects
Since the [root-sync][root-sync] object is associated with the folder `manifests/clusters`, the cluster level objects will be created from this folder. This includes creating CRDs, namespaces etc. So, for example, if you want to create a namespace as a platform admin, create a `yaml` file with the required K8s definition and save it under `manifests/clusters`. The namespace will be created on the cluster as soon as the sync happens.

Note that the owner of the repo should create a CODEOWNERS file to allow access to the platform admins to this folder so that only they can make cluster level objects. The Application teams should not have access to `manifests/clusters`.

In the section [04_setup_clusters][cluster-setup], you will create cluster scoped objects.


### Application-level objects
It is recommended to provide each Application its dedicated namespace. This means, only the application and related resources will be created in that namespace. The owner of the application or the app team will be get full access on the namespace so they can manage their application without having to be dependent on the platform admins.

Since the namespace is a cluster-scoped object, platform admin will need to create the namespace for the application and grant the app team members access on the namespace. Additionally, they will provide a  [repo-sync][repo-sync] repo to the app teams so they can use that to manage their application's kubernetes resource.  Once, this setup is done, the app team members can manage the application inside the namespace with the manifests in the [repo-sync][repo-sync] repo. 

In the section [05_setup_teams][team-setup], you will learn how the platform admins will set up an application by providing a namespace to the App team along with a [repo-sync][repo-sync] that the app teams will use to manage their applications.

In the section [06_operating_teams][operating-teams], you will learn how the app teams can use their [repo-sync][repo-sync] to manage thir application.

## Troubleshooting
If you do not have [GitHub pro membership][github-pro], you can not apply branch protection rules on your repositories in GitHub. This will cause `409 code` error when you run `terraform apply` . You can ignore these errors. The downside is that you will not get branch protection rules on your configsync repository and can accidentally push changes to the non-default branch which is `dev`. In other words, it will break the `GitOps` flow.  

## Contributing

*   [Contributing guidelines][contributing-guidelines]
*   [Code of conduct][code-of-conduct]

<!-- LINKS: https://www.markdownguide.org/basic-syntax/#reference-style-links -->

[contributing-guidelines]: CONTRIBUTING.md
[code-of-conduct]: code-of-conduct.md
[personal-access-token]: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens
[repo-sync]: https://cloud.google.com/anthos-config-management/docs/reference/rootsync-reposync-fields
[root-sync]: https://cloud.google.com/anthos-config-management/docs/reference/rootsync-reposync-fields
[cluster-setup]: ../04_setup_clusters/README.md
[team-setup]: ../05_setup_teams/README.md
[operating-teams]: ../06_operating_teams
[cluster]: ../02_gke
[github-pro]: https://docs.github.com/en/get-started/learning-about-github/githubs-plans
<!-- END_TF_DOCS -->
## Clean up

1. The easiest way to prevent continued billing for the resources that you created for this tutorial is to delete the project you created for the tutorial. Run the following commands from Cloud Shell:

   ```bash
    gcloud config unset project && \
    echo y | gcloud projects delete <PROJECT_ID>
   ```

2. If the project needs to be left intact, another option is to destroy the infrastructure created from this module. Note, this does not destroy the Cloud Storage bucket containing the Terraform state and service enablement created out of Terraform.

   ```bash
    cd ml-platform/03_configsync && \
    terraform destroy --auto-approve
   ```

