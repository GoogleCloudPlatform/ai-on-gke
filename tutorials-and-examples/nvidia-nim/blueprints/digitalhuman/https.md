# HTTPS endpoints for Digital Human for Customer Service on GKE

Deploying HTTPS endpoints for the digital human blueprint on GKE.

## Table of Contents

- [Prerequisetes](#prerequisites)
- [Setup](#setup)

## Prerequisites

- **kubectl:**  kubectl command-line tool installed and configured.
- **GKE credentials** Ensure you have the credentials to access the GKE cluster.
- **Certificates**  Privileges to create certificates.
- **IP Reservation** Privileges to reserve IP addresses.

## Setup

1. **Cluster update**: You'll need to update the cluster by enabling GKE Gateway controller and addon for HTTP LoadBalancing
    ```bash

    gcloud container clusters update "${CLUSTER_NAME}" \
      --location="${ZONE}"  \
      --gateway-api=standard

    gcloud container clusters update "${CLUSTER_NAME}" \
      --location="${ZONE}"  \
      --update-addons=HttpLoadBalancing=ENABLED

    ```

2. **Environment setup**: You'll set up a couple of environment variables to make the following steps easier and more flexible. These variables store important information like cluster names, machine types, and API keys. You need to update the variable values to match your needs and context.

    ```bash

    export NIMS="dighum-embedqa-e5v5 dighum-llama3-8b dighum-rerankqa-mistral4bv3 dighum-audio2face-3d dighum-fastpitch-tts dighum-maxine-audio2face-2d dighum-parakeet-asr-1-1b"
    export DOMAIN=<DOMAIN>

    ```

3. **Static IP Reservation**:

    ```bash

    for NIM in ${NIMS}; do
      gcloud compute addresses create ${NIM}-ip --global;
    done

    ```

4. **DNS**: Configure the DNS subdomains for each NIM. Our sub-domains for this example should be in this format <NIM>.<DOMAIN> (e.g. llama3-8b.example.com).

5. **Creating the SSL Certs**

    ```bash

    for NIM in ${NIMS}; do
      gcloud compute ssl-certificates create ${NIM}-cert --domains=${NIM}.${DOMAIN};
    done

    ```

6. **Create k8s service, gateway and http-route and healthcheck**
  
    ```bash

    for NIM in ${NIMS}; do
    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: Service
    metadata:
      name: ${NIM}-svc
    spec:
      selector:
        app: ${NIM}
      ports:
      - protocol: TCP
        port: 8000
        targetPort: 8000
    ---
    kind: Gateway
    apiVersion: gateway.networking.k8s.io/v1beta1
    metadata:
      name: ${NIM}-gw
    spec:
      gatewayClassName: gke-l7-global-external-managed
      listeners:
      - name: https
        protocol: HTTPS
        port: 443
        tls:
          mode: Terminate
          options:
            networking.gke.io/pre-shared-certs: ${NIM}-cert
      addresses:
      - type: NamedAddress
        value: ${NIM}-ip
    ---
    kind: HTTPRoute
    apiVersion: gateway.networking.k8s.io/v1beta1
    metadata:
      name: ${NIM}-httpr
    spec:
      parentRefs:
      - kind: Gateway
        name: ${NIM}-gw
      hostnames:
      - "${NIM}.${DOMAIN}"
      rules:
      - backendRefs:
        - name: ${NIM}-svc
          port: 8000
    ---
    apiVersion: networking.gke.io/v1
    kind: HealthCheckPolicy
    metadata:
      name: ${NIM}-hcheck
    spec:
      default:
        checkIntervalSec: 15
        timeoutSec: 1
        healthyThreshold: 1
        unhealthyThreshold: 2
        logConfig:
          enabled: true
        config:
          type: TCP
          httpHealthCheck:
            port: 8000
            requestPath: /v1/health/ready
      targetRef:
        group: ""
        kind: Service
        name: ${NIM}-svc
    EOF
    done

    ```

*The certificate can take 15 minutes to be attached to the LB

## Remove LB services

*Ensure that your HTTPS connection is working before remove the LB services

1. **Delete the old LB services**

    ```bash

    SERVICES=$(k get svc | awk '{print $1}' | grep -v NAME | grep '^dighum.*-lb$')

    for service in $SERVICES; do
      kubectl delete svc ${service}
    done

    ```
