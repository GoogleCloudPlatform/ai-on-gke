# AI on GKE

[![Deploy using Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https://github.com/umeshkumhar/ai-on-gke&cloudshell_tutorial=tutorial.md&cloudshell_workspace=./)

This repository contains assets related to AI/ML workloads on
[Google Kubernetes Engine (GKE)](https://cloud.google.com/kubernetes-engine/).







## Important Note
The use of the assets contained in this repository is subject to compliance with [Google's AI Principles](https://ai.google/responsibility/principles/)

## Licensing

* See [LICENSE](/LICENSE)

gcloud alpha infra-manager deployments apply projects/umeshkumhar/locations/us-central1/deployments/aiongke-deployment \
    --service-account=projects/umeshkumhar/serviceAccounts/aiongke-infra@umeshkumhar.iam.gserviceaccount.com \
    --git-source-repo=https://github.com/umeshkumhar/ai-on-gke \
    --git-source-directory=platform \
    --git-source-ref=main \
    --input-values=project_id=umeshkumhar,cluster_name=demo123


gcloud alpha infra-manager deployments describe projects/umeshkumhar/locations/us-central1/deployments/aiongke-deployment