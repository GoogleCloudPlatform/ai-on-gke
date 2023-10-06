# AI on GKE

[![Deploy using Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https://github.com/umeshkumhar/ai-on-gke&cloudshell_tutorial=tutorial.md&cloudshell_workspace=./)

This repository contains assets related to AI/ML workloads on
[Google Kubernetes Engine (GKE)](https://cloud.google.com/kubernetes-engine/).







## Important Note
The use of the assets contained in this repository is subject to compliance with [Google's AI Principles](https://ai.google/responsibility/principles/)

## Licensing

* See [LICENSE](/LICENSE)



        export CLUSTERNAME=$$(terraform -chdir="./platform/" output -raw cluster_name)
        export REGION=$$(terraform -chdir="./platform/" output -raw cluster_region')
        export PROJECT=$$(terraform -chdir="./platform/" output -raw project_id)