# Image URL to use all building/pushing image targets  
IMG ?= us-docker.pkg.dev/ai-on-gke/kuberay-tpu-webhook/tpu-webhook:v1.2.2-gke.1

# For europe, use europe-docker.pkg.dev/ai-on-gke/kuberay-tpu-webhook/tpu-webhook
  
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

# Run go fmt against code.
fmt:
	go fmt ./...

# Run go vet against code.
vet:
	go vet ./...

# Run go test against code.
test:
	go test ./...
  
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

