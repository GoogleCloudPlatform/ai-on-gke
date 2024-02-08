import yaml

with open("../jupyter_config/config-selfauth.yaml", "r") as yaml_file:
    data = yaml.safe_load(yaml_file)

data["hub"]["image"]["name"]="gcr.io/gke-ai-eco-dev/jupyterhub/k8s-hub"

with open("../jupyter_config/config-selfauth.yaml", 'w') as yaml_file:
    yaml.dump(data, yaml_file)