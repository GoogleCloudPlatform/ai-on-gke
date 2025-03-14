# TPU DRA driver

This helm chart is for running TPU DRA driver on GKE. The driver is in Private Preview stage now. 

## Overview

TPU DRA driver is only supported on GKE cluster version 1.32+
Make sure to disable the default tpu-device-plugin on the nodes. This can be done by add node label
`gke-no-default-tpu-device-plugin=true` and `gke-no-default-tpu-dra-plugin=true` when creating nodepool

Run `./install-tpu-dra-driver.sh` to install tpu-dra-driver on your GKE Cluster
nodes with TPU resources