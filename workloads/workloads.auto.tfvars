
##common variables  
## Need to pull this variables from tf output from previous platform stage
project_id = "ai-sandbox-4"
region     = "us-central1"
cluster_name   = "ml-cluster"

## this is required for terraform to connect to master and deploy workloads
#allow_update_authorised_networks = true

#######################################################
####    APPLICATIONS
#######################################################

## GKE environment variables
namespace       = "myray"
service_account = "myray-system-account"
enable_tpu      = false
enable_autopilot = false    # If false, creates GKE standard cluster # Needed to install or not nvidia driver # If = true, functionality not created yet.



## JupyterHub variables
create_jupyterhub = true                # Default = true, creates JupyterHub
create_jupyterhub_namespace = false     # Default = false, uses default ray namespace "myray". 
jupyterhub_namespace = "myray"          # If create_jupyterhub_namespace = false, then keep this same as namespace (from GKE variables)

