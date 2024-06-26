This module requires the cluster name to be passed in manually via the CLUSTER_NAME variable to filter metrics. This is a consequence of differing cluster name schemas between GKE and standard k8s clusters. Instructions for each are as follows if the cluster name isnt already known.

## For GKE clusters

Remove any charachters prior to and including the last underscore:
`kubectl config current-context | awk -F'_' ' { print $NF }'`

## For other clusters

The cluster name is simply:
 `kubectl config current-context`
