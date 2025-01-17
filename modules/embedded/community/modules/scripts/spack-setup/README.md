## Description

This module can be used to setup and install Spack on a VM. To actually run
Spack commands to install other software use the
[spack-execute](../spack-execute/) module.

This module generates a script that performs the following:

1. Install system dependencies needed for Spack
1. Clone Spack into a predefined directory
1. Check out a specific version of Spack

There are several options on how to consume the outputs of this module:

> [!IMPORTANT]
> Breaking changes between after v1.21.0. `spack-install` module replaced by
> `spack-setup` and `spack-execute` modules.
> [Details Below](#deprecations-and-breaking-changes)

## Examples

### `use` `spack-setup` with `spack-execute`

This will prepend the `spack-setup` script to the `spack-execute` commands.

```yaml
  - id: spack-setup
    source: community/modules/scripts/spack-setup

  - id: spack-build
    source: community/modules/scripts/spack-execute
    use: [spack-setup]
    settings:
      commands: |
        spack install gcc@10.3.0 target=x86_64

  - id: builder
    source: modules/compute/vm-instance
    use: [network1, spack-build]
```

### `use` `spack-setup` with `vm-instance` or Slurm module

This will run `spack-setup` scripts on the downstream compute resource.

```yaml
  - id: spack-setup
    source: community/modules/scripts/spack-setup

  - id: spack-installer
    source: modules/compute/vm-instance
    use: [network1, spack-setup]
```

OR

```yaml
  - id: spack-setup
    source: community/modules/scripts/spack-setup

  - id: slurm_controller
    source: community/modules/scheduler/schedmd-slurm-gcp-v5-controller
    use: [network1, partition1, spack-setup]
```

### Build `starup-script` with `spack-runner` output

This will use the generated `spack-setup` script as one step in `startup-script`.

```yaml
  - id: spack-setup
    source: community/modules/scripts/spack-setup

  - id: startup-script
    source: modules/scripts/startup-script
    settings:
      runners:
      - $(spack-setup.spack-runner)
      - type: shell
        destination: "my-script.sh"
        content: echo 'hello world'

  - id: workstation
    source: modules/compute/vm-instance
    use: [network1, startup-script]
```

To see a full example of this module in use, see the [hpc-slurm-gromacs.yaml] example.

[hpc-slurm-gromacs.yaml]: ../../../examples/hpc-slurm-gromacs.yaml

## Environment Setup

### Activating Spack

[Spack installation] produces a setup script that adds `spack` to your `PATH` as
well as some other command-line integration tools. This script can be found at
`<install path>/share/spack/setup-env.sh`. This script will be automatically
added to bash startup by any machine that runs the `spack_runner`.

If you have multiple machines that all want to use the same shared Spack
installation you can just have both machines run the `spack_runner`.

[Spack installation]: https://spack-tutorial.readthedocs.io/en/latest/tutorial_basics.html#installing-spack

### Managing Spack Python dependencies

Spack is configured with [SPACK_PYTHON] to ensure that Spack itself uses a
Python virtual environment with a supported copy of Python with the package
`google-cloud-storage` pre-installed. This enables Spack to use mirrors and
[build caches][builds] on Google Cloud Storage. It does not configure Python
packages *inside* Spack virtual environments. If you need to add more Python
dependencies for Spack itself, use the `spack python` command:

```shell
sudo -i spack python -m pip install package-name
```

[SPACK_PYTHON]: https://spack.readthedocs.io/en/latest/getting_started.html#shell-support
[builds]: https://spack.readthedocs.io/en/latest/binary_caches.html

## Spack Permissions

### System `spack` user is created - Default

By default this module will create a `spack` linux user and group with
consistent UID and GID. This user and group will own the Spack installation. To
allow a user to manually add Spack packages to the system Spack installation,
you can add the user to the spack group:

```sh
sudo usermod -a -G spack <username>
```

Log out and back in so the group change will take effect, then `<username>` will
be able to call `spack install <package>`.

> [!NOTE]
> A background persistent SSH connections may prevent the group change from
> taking effect.

You can use the `system_user_name`, `system_user_uid`, and `system_user_gid` to
customize the name and ids of the system user. While unlikely, it is possible
that the default `system_user_uid` or `system_user_gid` could conflict with
existing UIDs.

### Use and existing user

Alternatively, if `system_user_name` is a user already on the system, then this
existing user will be used for Spack installation.

#### OS Login User

If OS Login is enabled (default for most Cluster Toolkit modules) then you can
provide an OS Login user name:

```yaml
  - id: spack-setup
    source: community/modules/scripts/spack-setup
    settings:
      system_user_name: username_company_com
```

This will work even if the user has not yet logged onto the machine. When the
specified user does log on to the machine they will be able to call
`spack install` without any further configuration.

#### Pre-configured user

You can also use a startup script to configure a user:

```yaml
  - id: spack-setup
    source: community/modules/scripts/spack-setup
    settings:
      system_user_name: special-user

  - id: startup
    source: modules/scripts/startup-script
    settings:
      runners:
        - type: shell
          destination: "create_user.sh"
          content: |
            #!/bin/bash
            sudo useradd -u 799 special-user
            sudo groupadd -g 922 org-group
            sudo usermod -g org-group special-user
        - $(spack-setup.spack_runner)

  - id: spack-vms
    source: modules/compute/vm-instance
    use: [network1, startup]
    settings:
      name_prefix: spack-vm
      machine_type: n2d-standard-2
      instance_count: 5
```

### Chaining spack installations

If there is a need to have a non-root user to install spack packages it is
recommended to create a separate installation for that user and chain Spack installations
([Spack docs](https://spack.readthedocs.io/en/latest/chain.html#chaining-spack-installations)).

Steps to chain Spack installations:

1. Get the version of the system Spack:

    ```sh
    $ spack --version

    0.20.0 (e493ab31c6f81a9e415a4b0e0e2263374c61e758)
    #       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    # Note commit hash and use in next step
    ```

1. Clone a new spack installation:

    ```sh
    git clone -c feature.manyFiles=true https://github.com/spack/spack.git <new_location>/spack
    git -C <new_location>/spack checkout <commit_hash>
    ```

1. Point the new Spack installation to the system Spack installation. Create a
   file at `<new_location>/spack/etc/spack/upstreams.yaml` with the following
   contents:

    ```yaml
    upstreams:
      spack-instance-1:
        install_tree: /sw/spack/opt/spack/
    ```

1. Add the following line to your `.bashrc` to make sure the new `spack` is in
   your `PATH`.

   ```sh
   . <new_location>/spack/share/spack/setup-env.sh
   ```

## Deprecations and Breaking Changes

The old `spack-install` module has been replaced by the `spack-setup` and
`spack-execute` modules. Generally this change strives to allow for a more
flexible definition of a Spack build by using native Spack commands.

For every deprecated variable from `spack-install` there is documentation on how
to perform the equivalent action using `commands` and `data_files`. The
documentation can be found on the [inputs table](#inputs) below.

Below is a simple example of the same functionality shown before and after the
breaking changes.

```yaml
  # Before
  - id: spack-install
    source: community/modules/scripts/spack-install
    settings:
      install_dir: /sw/spack
      compilers:
      - gcc@10.3.0 target=x86_64
      packages:
      - intel-mpi@2018.4.274%gcc@10.3.0

- id: spack-startup
    source: modules/scripts/startup-script
    settings:
      runners:
      - $(spack.install_spack_deps_runner)
      - $(spack.install_spack_runner)
```

```yaml
  # After
  - id: spack-setup
    source: community/modules/scripts/spack-setup
    settings:
      install_dir: /sw/spack

  - id: spack-execute
    source: community/modules/scripts/spack-execute
    use: [spack-setup]
    settings:
      commands: |
        spack install gcc@10.3.0 target=x86_64
        spack load gcc@10.3.0 target=x86_64
        spack compiler find --scope site
        spack install intel-mpi@2018.4.274%gcc@10.3.0

- id: spack-startup
    source: modules/scripts/startup-script
    settings:
      runners:
      - $(spack-execute.spack-runner)
```

Although the old `spack-install` module will no longer be maintained, it is
still possible to use the old module in a blueprint by referencing an old
version from GitHub. Note the source line in the following example.

```yaml
  - id: spack-install
    source: github.com/GoogleCloudPlatform/hpc-toolkit//community/modules/scripts/spack-install?ref=v1.22.1&depth=1
```

## License

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
Copyright 2022 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 4.42 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >= 4.42 |
| <a name="provider_local"></a> [local](#provider\_local) | >= 2.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_startup_script"></a> [startup\_script](#module\_startup\_script) | github.com/GoogleCloudPlatform/hpc-toolkit//modules/scripts/startup-script | v1.39.0&depth=1 |

## Resources

| Name | Type |
|------|------|
| [google_storage_bucket.bucket](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [local_file.debug_file_shell_install](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_chmod_mode"></a> [chmod\_mode](#input\_chmod\_mode) | `chmod` to apply to the Spack installation. Adds group write by default. Set to `""` (empty string) to prevent modification.<br/>For usage information see:<br/>https://docs.ansible.com/ansible/latest/collections/ansible/builtin/file_module.html#parameter-mode | `string` | `"g+w"` | no |
| <a name="input_configure_for_google"></a> [configure\_for\_google](#input\_configure\_for\_google) | When true, the spack installation will be configured to pull from Google's Spack binary cache. | `bool` | `true` | no |
| <a name="input_deployment_name"></a> [deployment\_name](#input\_deployment\_name) | Name of deployment, used to name bucket containing startup script. | `string` | n/a | yes |
| <a name="input_install_dir"></a> [install\_dir](#input\_install\_dir) | Directory to install spack into. | `string` | `"/sw/spack"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Key-value pairs of labels to be added to created resources. | `map(string)` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project in which the HPC deployment will be created. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region to place bucket containing startup script. | `string` | n/a | yes |
| <a name="input_spack_profile_script_path"></a> [spack\_profile\_script\_path](#input\_spack\_profile\_script\_path) | Path to the Spack profile.d script. Created by this module | `string` | `"/etc/profile.d/spack.sh"` | no |
| <a name="input_spack_ref"></a> [spack\_ref](#input\_spack\_ref) | Git ref to checkout for spack. | `string` | `"v0.20.0"` | no |
| <a name="input_spack_url"></a> [spack\_url](#input\_spack\_url) | URL to clone the spack repo from. | `string` | `"https://github.com/spack/spack"` | no |
| <a name="input_spack_virtualenv_path"></a> [spack\_virtualenv\_path](#input\_spack\_virtualenv\_path) | Virtual environment path in which to install Spack Python interpreter and other dependencies | `string` | `"/usr/local/spack-python"` | no |
| <a name="input_system_user_gid"></a> [system\_user\_gid](#input\_system\_user\_gid) | GID used when creating system user group. Ignored if `system_user_name` already exists on system. Default of 1104762903 is arbitrary. | `number` | `1104762903` | no |
| <a name="input_system_user_name"></a> [system\_user\_name](#input\_system\_user\_name) | Name of system user that will perform installation of Spack. It will be created if it does not exist. | `string` | `"spack"` | no |
| <a name="input_system_user_uid"></a> [system\_user\_uid](#input\_system\_user\_uid) | UID used when creating system user. Ignored if `system_user_name` already exists on system. Default of 1104762903 is arbitrary. | `number` | `1104762903` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_controller_startup_script"></a> [controller\_startup\_script](#output\_controller\_startup\_script) | Spack installation script, duplicate for SLURM controller. |
| <a name="output_gcs_bucket_path"></a> [gcs\_bucket\_path](#output\_gcs\_bucket\_path) | Bucket containing the startup scripts for spack, to be reused by spack-execute module. |
| <a name="output_spack_path"></a> [spack\_path](#output\_spack\_path) | Path to the root of the spack installation |
| <a name="output_spack_profile_script_path"></a> [spack\_profile\_script\_path](#output\_spack\_profile\_script\_path) | Path to the Spack profile.d script. |
| <a name="output_spack_runner"></a> [spack\_runner](#output\_spack\_runner) | Runner to be used with startup-script module or passed to spack-execute module.<br/>- installs Spack dependencies<br/>- installs Spack <br/>- generates profile.d script to enable access to Spack<br/>This is safe to run in parallel by multiple machines. Use in place of deprecated `setup_spack_runner`. |
| <a name="output_startup_script"></a> [startup\_script](#output\_startup\_script) | Spack installation script. |
| <a name="output_system_user_name"></a> [system\_user\_name](#output\_system\_user\_name) | The system user used to install Spack. It can be reused by spack-execute module to install spack packages. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
