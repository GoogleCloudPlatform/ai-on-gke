# AI on GKE Benchmark Framework Orchestration

## Pre-requisites
* terraform
* jq
* sed

### Configuration
Configuration is split across config files where files you need to modify are and templates where files that are automatically filled based on outputs from previous stages.

### Running scripts
After you have filled the configuration in config folder run ``text-generation-inference-apply.sh`` which will run stage-1, stage-2 and text-generation-inference stages.

To destroy the resources that have been created run ``text-generation-inference-destroy.sh`` which will destroy text-generation-inference, stage-2 and stage-1 in that order.
