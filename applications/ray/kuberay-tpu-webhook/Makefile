# Image URL to use all building/pushing image targets  
IMG ?= us-docker.pkg.dev/ai-on-gke/kuberay-tpu-webhook/kuberay-tpu-webhook:v1.1
  
# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)  
ifeq (,$(shell go env GOBIN))  
GOBIN=$(shell go env GOPATH)/bin  
else  
GOBIN=$(shell go env GOBIN)  
endif  
  
all: webhook
  
# Build manager binary  
webhook:  
	go build -o bin/kuberay-tpu-webhook main.go
  
# Run against the configured Kubernetes cluster in ~/.kube/config  
run: webhook  
	go run ./main.go  
  
uninstall:  
	kubectl delete -f deployments/

# Deploy the webhook in-cluster
deploy:
	kubectl apply -f deployments/
  
# Build the docker image  
docker-build:
	docker build . -t ${IMG} 
  
# Push the docker image  
docker-push:  
	docker push ${IMG}

deploy-cert:
	kubectl apply -f certs/

uninstall-cert:
	kubectl delete -f certs/

tests:
	kubectl apply -f tests/

delete-tests:
	kubectl delete -f tests/
