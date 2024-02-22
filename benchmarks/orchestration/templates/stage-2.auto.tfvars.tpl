# can be obtained from stage-1 by running:
# terraform output -json  | jq '."fleet_host".value'
credentials_config = {
  fleet_host = FLEET_HOST
}

#terraform output -json  | jq '."project_id".value'
project_id = PROJECT_ID
