import yaml
import sys

config_file = "../jupyter_config/config-selfauth.yaml"
if len(sys.argv) == 2:
    autopilot = (sys.argv[1] == "true")
    if autopilot:
        config_file = "../jupyter_config/config-selfauth-autopilot.yaml"

with open(config_file, "r") as yaml_file:
    data = yaml.safe_load(yaml_file)

data["hub"]["config"]["DummyAuthenticator"]["password"] = "dummy"

with open(config_file, 'w') as yaml_file:
    yaml.dump(data, yaml_file)
