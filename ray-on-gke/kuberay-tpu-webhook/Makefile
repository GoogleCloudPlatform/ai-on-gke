# Image URL to use all building/pushing image targets  
IMG ?= ryanaoleary/kuberay-tpu-webhook:latest  
  
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

deploy: webhook  
	kubectl apply -f deployments/  
  
# Build the docker image  
docker-build: webhook  
	docker build . -t ${IMG} 
  
# Push the docker image  
docker-push:  
	docker push ${IMG}  
  
install-cert-manager:  
	kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

uninstall-cert-manager:
	kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

deploy-cert: webhook
	kubectl apply -f certs/

uninstall-cert: webhook
	kubectl delete -f certs/

install-reflector:
	kubectl apply -f https://github.com/emberstack/kubernetes-reflector/releases/latest/download/reflector.yaml

uninstall-reflector:
	kubectl delete -f https://github.com/emberstack/kubernetes-reflector/releases/latest/download/reflector.yaml

tests: webhook
	kubectl apply -f tests/

delete-tests: webhook
	kubectl delete -f tests/