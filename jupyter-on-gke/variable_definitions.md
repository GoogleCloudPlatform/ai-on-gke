# Glossary for variables

This README contains all the variables used by Terraform for installing Juypterhub on the GKE cluster.

## Table of Contents

* [namespace](#namespace)
* [create_namespace](#create_namespace)
* [add_auth](#add_auth)
* [project_id](#project_id)
* [location](#location)
* [service_name](#service_name)
* [enable_iap_service](#enable_iap_service)
* [brand](#brand)
* [support_email](#support_email)
* [url_domain_addr](#url_domain_addr)
* [url_domain_name](#url_domain_name)

### namespace

The namespace that Jupyterhub and rest of the other resources will be installed/allocated in. If using Jupyterhub with the Ray module (`ai-on-gke/ray-on-gke/`), it is recommanded to have this namespace the same as the one with Ray.

### create_namespace

Flag that if enabled, will create a namespace for the user using the [namespace](#namespace) field.

### add_auth

Flag that will enable IAP on Jupyterhub. Resources that will be created along with enable IAP:
    1. Global IP Address (If none is provided)
    2. Backend Config. Deployment that triggers enabling IAP.
    3. Managed Certificate. Deployment that creates a Google Managed object for SSL certificates
    4. Ingress. Deployment that creates an Ingress object that will connect to the Jupyterhub Proxy

### project_id

Name of the project where the cluster lives. Used to retrieve the project number as well as used in numerous resources.

### location

Location of the GKE cluster. Used by the terraform provider.

### service_name

Name of the Backend Service that gets created when enabling IAP.

### enable_iap_service

Flag that will enable the IAP Service API for the user on the project. If it is already enabled, leave it as false.

### brand

Name of the brand used for creating IAP OAuth clients. Currently only one is allowed per project. If there is already a brand, leave it empty.
Uses [support_email](#support_email)

### support_email

Support email assocated with the [brand](#brand). Used as a point of contact for consent for the ["OAuth Consent" in Pantheon](https://pantheon.corp.google.com/apis/credentials/consent). It will not be used if brand is empty.

### url_domain_addr

Provided by the user if they want to bring their own URL/Domain. Used by the IAP resources if filled in. Filling this in will disable automatic global IP reservation. Must also fill in [url_domain_name](#url_domain_name).

### url_domain_name

This variable will only be used if [url_domain_addr](#url_domain_addr) is provided. It is the name associated with the domain provided by the user. Since we are using Ingress, it will require the `kubernetes.io/ingress.global-static-ip-name` annotation along with the name associated.
