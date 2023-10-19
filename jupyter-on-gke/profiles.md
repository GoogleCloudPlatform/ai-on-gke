# Jupyterhub Profiles

## Default Profiles

By default, there are 3 pre-set profiles for Jupyterhub:

![Profiles Page](images/image.png)

As the description for each profiles explains, each profiles uses a different resource.

1. First profile uses CPUs and uses the image: `jupyter/tensorflow-notebook` with tag `python-3.10`

2. Second profile uses 2 T4 GPUs and the image: `jupyter/tensorflow-notebook:python-3.10` with tag `python-3.10` [^1]

3. Third profile uses 2 A100 GPUs and the image: `jupyter/tensorflow-notebook:python-3.10` with tag `python-3.10` [^1]

## Editting profiles

You can change the image used by these profiles, change the resources, and add specific hooks to the profiles

Within the [`config.yaml`](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/jupyter-on-gke/jupyter_config/config.yaml), the profiles sit under the `singleuser` key:

``` yaml
singleuser:
    cpu:
        ...
    memory:
        ...
    image:
        name: jupyter/tensorflow-notebook
        tag: python-3.10
    ...
    profileList:
    ...
```

### Image

The default image used by all three of the profiles is `jupyter/tensorflow-notebook:python-3.10`

1. For profile 1, it uses the: `default: true` field. This means that all the default configs under `singleuser` are used.

2. For profile 2 and 3, the images are defined under `kubespawner_override`

``` yaml
    display_name: "Profile2 name"
        description: "description here"
        kubespawner_override:
            image: jupyter/tensorflow-notebook:python-3.10
    ...
```

Kubespanwer_override is a dictionary with overrides that gets applied through the Kubespawner. [^2]

More images of tensorflow can be found [here](https://hub.docker.com/r/jupyter/tensorflow-notebook)

### Resources

Each of the users get a part of the memory and CPU and the resources are by default:

``` yaml
    cpu:
        limit: .5
        guarantee: .5
    memory:
        limit: 1G
        guarantee: 1G
```

The _limit_ if the reousrce sets a hard limit on how much of that resource can the user have.
The _guarantee_ meaning the least amount of resource that will be available to the user at all times.

Similar to overriding images, the resources can also be overwritten by using `kubespawner_override`:

``` yaml
    kubespawner_override:
        cpu_limit: .7
        cpu_guarantee: .7
        mem_limit: 2G
        mem_guarantee: 2G
        nvidia.com/gpu: "2"
```

### Node/GPU

Jupyterhub config allows the use of [nodeSelector](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector). This is the way the profiles specify which node/GPU it wants

``` yaml
nodeSelector:
    iam.gke.io/gke-metadata-server-enabled: "true"
    cloud.google.com/gke-accelerator: "nvidia-tesla-t4"
```

Override using `kubespwaner_override`:

``` yaml
    kubespawner_override:
        node_selector:
          cloud.google.com/gke-accelerator: "nvidia-tesla-a100"
```

The possible GPUs are:

1. nvidia-tesla-k80
2. nvidia-tesla-p100
3. nvidia-tesla-p4
4. nvidia-tesla-v100
5. nvidia-tesla-t4
6. nvidia-tesla-a100
7. nvidia-a100-80gb
8. nvidia-l4

### Example profile

Example of a profile that overrides the default values:

``` yaml
  - display_name: "Learning Data Science"
    description: "Datascience Environment with Sample Notebooks"
    kubespawner_override:
        cpu_limit: .5
        cpu_guarantee: .5
        mem_limit: 1G
        mem_guarantee: 1G
    image: jupyter/datascience-notebook:2343e33dec46
    lifecycle_hooks:
        postStart:
        exec:
            command:
            - "sh"
            - "-c"
            - >
                gitpuller https://github.com/data-8/materials-fa17 master materials-fa;
```

### Additional Overrides

With `kubespanwer_override` there are additional overrides that could be done, including `lifecycle_hooks`, `storage_capacity`, and `storage class`
Fields can be found [here](https://jupyterhub-kubespawner.readthedocs.io/en/latest/spawner.html)

[^1]: If using Standard clusters, the cluster must have at least 2 of the GPU type ready
[^2]: More information on Kubespawner [here](https://github.com/jupyterhub/kubespawner/blob/main/kubespawner/spawner.py)
