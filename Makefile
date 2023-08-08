current-project:= gcloud config get-value project 2> /dev/null

init: 
	gcloud init \
	&& cd ./ray-on-gke/platform/ && terraform init \
	&& cd ../user/ && terraform init \
	&& cd ./monitoring && terraform init \
	&& cd ./jupyterhub/ && terraform init 

gcloud-auth-cluster: 
	gcloud container clusters get-credentials $(NAME) --location $(LOCATION)

plan: PROJECT ?= $(shell $(current-project))
plan: LOCATION ?= us-central1-b
plan: NAME ?= ml-cluster
plan: AUTOPILOT ?= false
plan: TF-DIR ?= platform
plan:
	cd ./ray-on-gke/$(TF-DIR)/ && terraform plan \
	-var project_id=$(PROJECT) \
	-var region=$(LOCATION) \
	-var cluster_name=$(NAME) \
	-var enable_autopilot=$(AUTOPILOT) \

create-cluster: PROJECT ?= $(shell $(current-project))
create-cluster: LOCATION ?= us-central1
create-cluster: NAME ?= ml-cluster
create-cluster: AUTOPILOT ?= false
create-cluster:
	cd ./ray-on-gke/platform/ && \
	terraform apply -auto-approve \
	-var project_id=$(PROJECT) \
	-var region=$(LOCATION) \
	-var cluster_name=$(NAME) \
	-var enable_autopilot=$(AUTOPILOT) \
	&& cd ../../ && $(MAKE) gcloud-auth-cluster NAME=$(NAME) LOCATION=$(LOCATION) 

build-user: PROJECT ?= $(shell $(current-project))
build-user: SA-ACCOUNT-NAME ?= ray
build-user: NAMESPACE ?= ray
build-user:
	cd ./ray-on-gke/user/ && \
	terraform apply -auto-approve \
	-var project_id=$(PROJECT) \
	-var service_account=$(SA-ACCOUNT-NAME) \
	-var namespace=$(NAMESPACE) 

build-jupyterhub: CREATE_NAMESPACE ?= false
build-jupyterhub: NAMESPACE ?= ray
build-jupyterhub: NAMESPACE ?= ray
build-jupyterhub: 
	cd ./ray-on-gke/user/jupyterhub/ \
	&& terraform apply -auto-approve \
	-var namespace=$(NAMESPACE) \
	-var create_namespace=$(CREATE_NAMESPACE) \
	&& echo "IP of JupyterHub Ednpoint" \
	&& cd ../../../ && $(MAKE) get-jupyter-ip NAMESAPCE=$(NAMESPACE)

add-monitoring: PROJECT ?= $(shell $(current-project))
add-monitoring: NAMESPACE ?= ray
add-monitoring:
	cd ./ray-on-gke/user/monitoring/ \
	&& terraform apply -auto-approve \
	-var project_id=$(PROJECT) \
	-var namespace=$(NAMESPACE) 

get-jupyter-ip: NAMESPACE ?= ray
get-jupyter-ip:
	kubectl get svc proxy-public --namespace=$(NAMESPACE) -o jsonpath="{.status.loadBalancer.ingress[0].ip}" && echo "\n"

destroy-everything: SA-ACCOUNT-NAME ?= ray
destroy-everything: NAMESPACE ?= ray
destroy-everything: 
	$(MAKE) delete-jupyterhub \
	&& $(MAKE) delete-monitoring \
	&& $(MAKE) delete-user-resource NAMESPACE=$(NAMESPACE) SA-ACCOUNT-NAME=$(SA-ACCOUNT-NAME) \
	&& $(MAKE) delete-cluster 

delete-cluster: 
	cd ./ray-on-gke/platform/ && terraform destroy -auto-approve

delete-user-resource: SA-ACCOUNT-NAME ?= ray
delete-user-resource: NAMESPACE ?= ray
delete-user-resource:
	cd ./ray-on-gke/user/ && terraform destroy -auto-approve -var namespace=$(NAMESPACE) -var service_account=$(SA-ACCOUNT-NAME)

delete-monitoring: 
	cd ./ray-on-gke/user/monitoring && terraform destroy -auto-approve

delete-jupyterhub:
	cd ./ray-on-gke/user/jupyterhub && terraform destroy -auto-approve

clean-tfstate: TF-DIR ?= platform
clean-tfstate:
	cd ./ray-on-gke/$(TF-DIR)/ && rm terraform.tfstate terraform.tfstate.backup

test-stuff:
	echo "testing 123" && echo "here" && kubectl get svc proxy-public -o jsonpath="{.status.loadBalancer.ingress[0].ip}" && echo 