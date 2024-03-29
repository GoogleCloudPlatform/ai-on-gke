# Machine learning platform (MLP) on GKE reference architecture for enabling Machine Learning Operations (MLOps)

## Platform Principles

This reference architecture demonstrates how to build a GKE platform that facilitates Machine Learning. The reference architecture is based on the following principles:

- The platform admin will create the GKE platform using IaC tool like [Terraform][terraform]. The IaC will come with re-usable modules that can be referred to create more resources as the demand grows.
- The platform will be based on [GitOps][gitops].
- After the GKE platform has been created, cluster scoped resources on it will be created through [Config Sync][config-sync] by the admins.
- Platform admins will create a namespace per application and provide the application team member full access to it.
- The namespace scoped resources will be created by the Application/ML teams either via [Config Sync][config-sync] or through a deployment tool like [Cloud Deploy][cloud-deploy]

## CUJ and Personae addressed in the reference architecture

### Persona : Platform Admin

**CUJ 1** : Provide templates with built-in standard practices to stamp out GKE platforms to be used by ML Engineers, Data Scientists and Application teams.

**CUJ 2** : Provide GKE clusters.

**CUJ 2** : Provide space for the teams on GKE cluster to run their workloads and the permissions following the principle of least privilege.

**CUJ 3** : Provide secure methods to the ML Engineers, Data Scientist, Application teams and the Operators to connect to the private GKE clusters.

**CUJ 4** : Enforcing security policies on the underlying platform.

### Persona : ML Engineers

**CUJ 1** : Use ML tools like `ray` to perform their day to day tasks like data pre-processing, ML training etc.

**CUJ 2** : Use a development environment like Jupyter Notebook for faster inner loop of ML development. **[TBD]**

### Persona : Operators

**CUJ 1**: Act as a bridge between the Platform admins and the ML Engineers by providing and maintaining software needed by the ML engineers so they can focus on their job.

**CUJ 2**: Deploying the models. **[TBD]**

**CUJ 3**: Building observability on the models. **[TBD]**

**CUJ 4**: Operationalizing the models. **[TBD]**

## Prerequisites

- This guide is meant to be run on [Cloud Shell](https://shell.cloud.google.com) which comes preinstalled with the [Google Cloud SDK](https://cloud.google.com/sdk) and other tools that are required to complete this tutorial.
- Familiarity with following
  - [Google Kubernetes Engine][gke]
  - [Terraform][terraform]
  - [git][git]
  - [Google Configuration Management root-sync][root-sync]
  - [Google Configuration Management repo-sync][repo-sync]
  - [GitHub][github]

## Deploy the platform

[Sandbox Reference Architecture Guide](examples/platform/sandbox/README.md): Set up an environment to familiarize yourself with the architecture and get an understanding of the concepts.

## Use cases

- [Distributed Data Processing with Ray](examples/use-case/ray/dataprocessing/README.md): Run a distributed data processing job using Ray.

[gitops]: https://about.gitlab.com/topics/gitops/
[repo-sync]: https://cloud.google.com/anthos-config-management/docs/reference/rootsync-reposync-fields
[root-sync]: https://cloud.google.com/anthos-config-management/docs/reference/rootsync-reposync-fields
[config-sync]: https://cloud.google.com/anthos-config-management/docs/config-sync-overview
[cloud-deploy]: https://cloud.google.com/deploy?hl=en
[terraform]: https://www.terraform.io/
[gke]: https://cloud.google.com/kubernetes-engine?hl=en
[git]: https://git-scm.com/
[github]: https://github.com/
[gcp-project]: https://cloud.google.com/resource-manager/docs/creating-managing-projects
[personal-access-token]: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens
[machine-user-account]: https://docs.github.com/en/get-started/learning-about-github/types-of-github-accounts
