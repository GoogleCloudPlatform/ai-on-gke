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
# Reference architecture demonstrating how to build your ML platform on GKE.

## Purpose

This tutorial demonstrates repeatable patterns to setup a multi environment ML platform on private [Google Kubernetes Engine](https://cloud.google.com/kubernetes-engine/docs/concepts/kubernetes-engine-overview) (GKE) that can be extended for end-to-end MLOps. 

It addresses following personae and provides means to automate and simplify their CUJs.

### Platform Admin

**CUJ 1** : Provide templates with built-in standard practices to stamp out GKE platforms to be used by ML Engineers/Data Scientist.

**CUJ 2** : Provide space for the ML teams on GKE cluster to run their workloads and the permissions following the principle of least privilege. 

**CUJ 3** : Provide secure methods to the ML teams and the Operators to connect to the private GKE clusters.

**CUJ 4** : Enforcing security policies on the underlying platform.



### ML Engineers

**CUJ 1** : Use ML tools like `ray` to perform their day to day tasks like data pre-processing, ML training etc.

**CUJ 2** : Use a development environment like Jupyter Notebook for faster inner loop of ML development. **[TBD]**

### Operators

**CUJ 1**: Act as a bridge between the Platform admins and the ML Engineers by providing and maintaining software needed by the ML engineers so they can focus on their job.

**CUJ 2**: Deploying the models. **[TBD]**

**CUJ 3**: Building observability on the models. **[TBD]**

**CUJ 4**: Operationalizing the models. **[TBD]**

## Prerequistes

1. This tutorial has been tested on [Cloud Shell](https://shell.cloud.google.com) which comes preinstalled with [Google Cloud SDK](https://cloud.google.com/sdk) is required to complete this tutorial.

## Deploy resources.

Follow these steps in order to build the platform and use it.

- Run Terraform in [01_gcp_project folder][projects]. This module creates GCP projects for your ML environments. This is an optional module. If you already have created GCP projects, directly run 02_gke module.

- Run Terraform in [02_gke folder][gke]. This modules creates private GKE clusters for each environment. 

- Run Terraform in [03_configsync folder][configsync]. This modules enables Config management on GKE clusters, creates a repository in GitHub and creates a [root-sync][root-sync] on the clusters connected to the repo.

- Run steps in [04_setup_clusters][setup-clusters]. This modules walks through how as platform admin you can set up  cluster level software to the ML teams.

- Run steps in [05_setup_teams][setup-teams]. This modules walks through how as platform admin you can set up spaces for ML teams on the cluster and transfer ownership to operators to maintain that space.

- Run steps in [06_operating_teams][operating-teams]. This module walks through how as an operator you will provide the software required by ML engineers.


[projects]: ./01_gcp_project/README.md
[gke]: ./02_gke/README.md
[configsync]: ./03_configsync/README.md
[setup-clusters]: ./04_setup_clusters/README.md
[setup-teams]: ./05_setup_teams/README.md
[operating-teams]: ./06_operating_teams/README.md
[repo-sync]: https://cloud.google.com/anthos-config-management/docs/reference/rootsync-reposync-fields
[root-sync]: https://cloud.google.com/anthos-config-management/docs/reference/rootsync-reposync-fields