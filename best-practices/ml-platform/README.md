# Machine learning platform (MLP) on GKE reference architecture for enabling Machine Learning Operations (MLOps)

## Platform Principles

This reference architecture demonstrates how to build a GKE platform that facilitates Machine Learning. The reference architecture is based on the following principles:

- The platform admin will create the GKE platform using IaC tool like [Terraform][terraform]. The IaC will come with re-usable modules that can be referred to create more resources as the demand grows.
- The platform will be based on [GitOps][gitops].
- After the GKE platform has been created, cluster scoped resources on it will be created through [Config Sync][config-sync] by the admins.
- Platform admins will create a namespace per application and provide the application team member full access to it.
- The namespace scoped resources will be created by the Application/ML teams either via [Config Sync][config-sync] or through a deployment tool like [Cloud Deploy][cloud-deploy]

For an outline of products and features used in the platform, see the [Platform Products and Features](/best-practices/ml-platform/docs/platform/products-and-features.md) document.

## Critical User Journeys (CUJs)

### Persona : Platform Admin

- Offer a platform that incorporates established best practices.
- Grant end users the essential resources, guided by the principle of least privilege, empowering them to manage and maintain their workloads.
- Establish secure channels for end users to interact seamlessly with the platform.
- Empower the enforcement of robust security policies across the platform.

### Persona : Machine Learning Engineer

- Deploy the model with ease and make the endpoints available only to the intended audience
- Continuously monitor the model performance and resource utilization
- Troubleshoot any performance or integration issues
- Ability to version, store and access the models and model artifacts:
  - To debug & troubleshoot in production and track back to the specific model version & associated training data
  - To quick & controlled rollback to a previous, more stable version
- Implement the feedback loop to adapt to changing data & business needs:
  - Ability to retrain / fine-tune the model.
  - Ability to split the traffic between models (A/B testing)
  - Switching between the models without breaking inference system for the end-users
- Ability to scaling up/down the infra to accommodate changing needs
- Ability to share the insights and findings with stakeholders to take data-driven decisions

### Persona : Machine Learning Operator

- Provide and maintain software required by the end users of the platform.
- Operationalize experimental workload by providing guidance and best practices for running the workload on the platform.
- Deploy the workloads on the platform.
- Assist with enabling observability and monitoring for the workloads to ensure smooth operations.

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

[Playground Reference Architecture](examples/platform/playground/README.md): Set up an environment to familiarize yourself with the architecture and get an understanding of the concepts.

## Use cases

- [Distributed Data Processing with Ray](examples/use-case/data-processing/ray/README.md): Run a distributed data processing job using Ray.

## Resources

- [Packaging Jupyter notebooks](docs/notebook/packaging.md): Patterns and tools to get your ipynb's ready for deployment in a container runtime.

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
