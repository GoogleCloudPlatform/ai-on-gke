# configuration Specify configuration for Flyte
configuration:
  # database Specify configuration for Flyte's database connection
  database:
    # username Name for user to connect to database as
    username: "${CLOUDSQL_USERNAME}"
    # password Password to connect to database with
    # If set, a Secret will be created with this value and mounted to Flyte pod
    password: >-
      ${CLOUDSQL_PASSWORD}
    # host Hostname of database instance
    host: "${CLOUDSQL_IP}"
    # dbname Name of database to use
    dbname: "${CLOUDSQL_DBNAME}"
  # storage Specify configuration for object store
  storage:
    # metadataContainer Bucket to store Flyte metadata
    metadataContainer: "${BUCKET_NAME}"
    # userDataContainer Bucket to store Flyte user data
    userDataContainer: "${BUCKET_NAME}"
    # provider Object store provider (Supported values: s3, gcs)
    provider: gcs
    # providerConfig Additional object store provider-specific configuration
    providerConfig:
      # gcs Provider configuration for GCS object store
      gcs:
        # project Google Cloud project in which bucket resides
        project: "${PROJECT_ID}"
  # logging Specify configuration for logs emitted by Flyte
  logging:
    # plugins Specify additional logging plugins
    plugins:
      # stackdriver Configure logging plugin to have logs visible in StackDriver
      stackdriver:
        enabled: true
        templateUri: |
          "https://console.cloud.google.com/logs/query;query=resource.labels.namespace_name%3D%22{{.namespace}}%22%0Aresource.labels.pod_name%3D%22{{.podName}}%22%0Aresource.labels.container_name%3D%22{{.containerName}}%22?project=${PROJECT_ID}&angularJsUrl=%2Flogs%2Fviewer%3Fproject%3D${PROJECT_ID}"

  # inline Specify additional configuration or overrides for Flyte, to be merged with the base configuration
  inline:
    #This section automates the IAM Role annotation for the default KSA on each project namespace to enable IRSA
    #Learn more: https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html
    cluster_resources:
      customData:
      - production:
        - defaultIamServiceAccount:
            value: "${FLYTE_IAM_SA_EMAIL}"
      - staging:
        - defaultIamServiceAccount:
            value: "${FLYTE_IAM_SA_EMAIL}"
      - development:
        - defaultIamServiceAccount:
            value: "${FLYTE_IAM_SA_EMAIL}"
    plugins:
      k8s:
        inject-finalizer: true
        gpu-device-node-label: cloud.google.com/gke-accelerator
        gpu-partition-size-node-label: cloud.google.com/gke-gpu-partition-size
        resource-tolerations:
          - nvidia.com/gpu:
            - key: "nvidia.com/gpu"
              operator: "Equal"
              value: "present"
              effect: "NoSchedule"
    # Configuration for the Datacatalog engine, used when caching is enabled
    # Learn more: https://docs.flyte.org/en/latest/deployment/configuration/generated/datacatalog_config.html
    storage:
      cache:
        max_size_mbs: 10
        target_gc_percent: 100

flyte-core-components:
  admin:
    seedProjects:
      - flytesnacks
    seedProjectsWithDetails:
      - name: flytesnacks
        description: Default project setup.

# clusterResourceTemplates Specify templates for Kubernetes resources that should be created for new Flyte projects
clusterResourceTemplates:
  # inline Specify additional cluster resource templates, to be merged with the base configuration
  inline:
    #This section automates the creation of the project-domain namespaces
    001_namespace.yaml: |
      apiVersion: v1
      kind: Namespace
      metadata:
        name: '{{ namespace }}'
    # This block performs the automated annotation of KSAs across all project-domain namespaces. Make sure to bind the KSA to the GSA after KSAs are created: https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#authenticating_to
    002_serviceaccount.yaml: |
      apiVersion: v1
      kind: ServiceAccount
      metadata:
        name: default
        namespace: '{{ namespace }}'
        annotations:
          iam.gke.io/gcp-service-account: '{{ defaultIamServiceAccount }}'

# serviceAccount Configure Flyte ServiceAccount
serviceAccount:
  # create Create ServiceAccount for Flyte
  create: true
  #Automates annotation of default flyte-binary KSA. Make sure to bind the KSA to the GSA: https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#authenticating_to
  annotations:
    iam.gke.io/gcp-service-account: "${FLYTE_IAM_SA_EMAIL}"
# rbac Configure Kubernetes RBAC for Flyte
rbac:
  # create Create ClusterRole and ClusterRoleBinding resources
  create: true
  # extraRules Add additional rules to the ClusterRole
  extraRules:
   - apiGroups:
      - ""
     resources:
      - serviceaccounts
     verbs:
      - create
      - get
      - patch
