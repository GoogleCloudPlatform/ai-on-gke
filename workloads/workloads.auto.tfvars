
##common variables
project_id = "umeshkumhar"
region     = "us-central1"

## this is required for terraform to connect to master and deploy workloads
#allow_update_authorised_networks = true

#######################################################
####    APPLICATIONS
#######################################################

## GKE environment variables
namespace       = "myray"
service_account = "myray-system-account"
enable_tpu      = false

## JupyterHub variables
create_jupyterhub = true                # Default = true, creates JupyterHub
create_jupyterhub_namespace = false     # Default = false, uses default ray namespace "myray". 
jupyterhub_namespace = "myray"          # If create_jupyterhub_namespace = false, then keep this same as namespace (from GKE variables)

