# VMware vSphere, VirtualBox (Vagrant) Packer and Terraform Templates for Rancher

> *Note*
> 
> This repository initially contained templates for Linux VMs. As they were not regularly used or tested, they have been removed. Refer to [packer-examples-for-vsphere](https://github.com/vmware-samples/packer-examples-for-vsphere) for more up to date examples of how to template Linux VMs.

> ⚠️ **WARNING**:
>
> While maintaining these templates, you **MUST** ensure that you do not commit sensitive information, such as passwords, keys, certificates, etc.

<img alt="VMware vSphere 7.0 Update 2+" src="https://img.shields.io/badge/VMware%20vSphere-7.0%20Update%202+-blue?style=for-the-badge">
<img alt="Packer 1.8.0+" src="https://img.shields.io/badge/HashiCorp%20Packer-1.8.0+-blue?style=for-the-badge&logo=packer">

## Table of Contents
1. [Introduction](#introduction)
2. [Requirements](#requirements)
3. [Configuration](#configuration)
4. [Build](#build)
   - [vSphere template build process](#vsphere-template-build-process)
   - [Vagrant template build process](#vagrant-template-build-process)
5. [Troubleshoot](#troubleshoot)
6. [Credits](#credits)

## Introduction

This repository is a fork of the upstream [packer-examples-for-vsphere](https://github.com/vmware-samples/packer-examples-for-vsphere) and has been adapted to support Windows machine image templates that work well with Rancher and RKE2. It contains Packer HCL templates and example Terraform plans to build Windows VM images for both VMware vSphere and VirtualBox (Vagrant) targets.

- vSphere: templates use the `vsphere-iso` Packer builder and support publishing to a vSphere Content Library.
- Vagrant / VirtualBox: templates produce VirtualBox images packaged as Vagrant boxes (see builds/.../vagrant).

By default, vSphere builds upload artifacts to a vSphere Content Library as an OVF template and destroy the temporary build VM. If an item of the same name exists, Packer updates the existing template.

The following builds are available:

**Microsoft Windows** - _Core and Desktop Experience_
* Microsoft Windows Server 2025 - Standard and Datacenter
* Microsoft Windows Server 2022 - Standard and Datacenter
* Microsoft Windows Server 2019 - Standard and Datacenter

## Requirements

This project requires several common tools for both vSphere and Vagrant/VirtualBox workflows. 

- HashiCorp Packer >= 1.8.0
- VirtualBox (for Vagrant/VirtualBox builds) and Vagrant
- VMware vSphere environment (for vsphere-iso builds) and credentials (if you plan vSphere builds)
- Git
- mkisofs/xorriso (or hdiutil on macOS) — for ISO manipulation in some helper scripts
- mkpasswd (part of whois on some platforms) — used by some Windows provisioning helpers
- coreutils (optional, depending on platform/script usage)
- gomplate (optional, used by some template generation scripts)

Additional software packages
- Packer plugins (installed via `packer init` or manually): `packer-builder-vsphere`, `packer-builder-virtualbox`, `packer-post-processor-vagrant`, `packer-provisioner-shell`, `packer-provisioner-windows-update`, etc.
- Terraform (if using the included example Terraform plans)
- Any platform-specific tooling required to interact with your virtualization provider (vSphere SDK/CLI, VirtualBox Guest Additions management tools, etc.)

**Operating Systems**:
* openSUSE Tumbleweed
* Ubuntu Server 20.04 LTS
* macOS

**Additional Software Packages**:

The following software packages must be installed on the Packer host:

**Required vSphere Platform**:
* VMware Cloud Foundation 4.2 or higher, or
* VMware vSphere 7.0 Update 2 or higher

## Configuration

This project has the following structure

```
├── builds
│   └── windows
│       └── server
│           ├── 2025
│           |    ├──  vagrant # VirtualBox / Vagrant Packer templates and files
│           |    |    ├── *.pkr.hcl
│           |    |    ├── *.auto.pkrvars.hcl
│           |    |    └── data
│           |    |        └── autounattend.pkrtpl.hcl
│           |    └── vsphere # vSphere Packer templates and files
│           |         ├ *.pkr.hcl
│           |         ├── *.auto.pkrvars.hcl
│           |         └── data
│           |             └── autounattend.pkrtpl.hcl
│           ├── 2022
│           |    ├──  vagrant
│           |    |    ├── *.pkr.hcl
│           |    |    ├── *.auto.pkrvars.hcl
│           |    |    └── data
│           |    |        └── autounattend.pkrtpl.hcl
│           |    └── vsphere
│           |         ├ *.pkr.hcl
│           |         ├── *.auto.pkrvars.hcl
│           |         └── data
│           |             └── autounattend.pkrtpl.hcl
│           └── 2019
│               ├──  vagrant 
│               |    ├── *.pkr.hcl
│               |    ├── *.auto.pkrvars.hcl
│               |    └── data
│               |        └── autounattend.pkrtpl.hcl
│               └── vsphere 
│                    ├ *.pkr.hcl
│                    ├── *.auto.pkrvars.hcl
│                    └── data
│                        └── autounattend.pkrtpl.hcl
├── create/        # helper scripts (e.g., create/vagrant-build.sh)
├── config/        # configuration; generate and edit for your environment
├── scripts/       # shared provisioning and helper scripts executed during templating
└── examples/      # example Terraform or usage snippets
```

The files are distributed in the following directories.
* **`builds`** - contains the templates, variables, and configuration files for the machine image build.
* **`scripts`** - contains the scripts to initialize and prepare a Windows machine image template.
  * **This includes installing and configuring important dependencies, such as CloudBase init, as well as configuring access over SSH.**  
* **`certificates`** - contains the Trusted Root Authority certificates for a Windows machine image build.
* **`manifests`** - manifests created after the completion of the machine image build.
* **`terraform`** - contains example Terraform plans to test machine image builds.

## Preparing for vSphere templating 

### Step: Download the Guest Operating Systems ISOs

> *Note*
> 
> If you're building a Vagrant box, you can instead use the `iso_url` variable. Packer will automatically download the ISO at that URL and cache it. This is not supported for vSphere builds.

1. Download the x64 guest operating system [.iso][iso] images.
    **Microsoft Windows**
    * Microsoft Windows Server 2022
      * [Download](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2019) the latest Evaluation edition of Windows Server 2019
    * Microsoft Windows Server 2019
      * [Download](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2022) the latest Evaluation edition of Windows server 2022

3. Obtain the checksum type (_e.g._ `sha256`, `md5`, etc.) and checksum value for each guest operating system `.iso` image from the vendor. This will be use in the build input variables.

4. [Upload][vsphere-upload] your guest operating system `.iso` images to the ISO datastore and paths that will be used in your variables.

    **Example**: `config/common.pkvars.hcl`

    ```hcl
    common_iso_datastore = "sfo-w01-cl01-ds-nfs01"
    iso_path             = "iso/linux/photon"
    iso_file             = "photon-4.0-xxxxxxxxx.iso"
    iso_checksum_type    = "md5"
    iso_checksum_value   = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    ```

### Step: Configure Service Account Privileges in vSphere

Create a custom vSphere role with the required privileges to integrate HashiCorp Packer with VMware vSphere. A service account can be added to the role to ensure that Packer has least privilege access to the infrastructure. Clone the default **Read-Only** vSphere role and add the following privileges:

Category        | Privilege                                           | Reference
----------------|-----------------------------------------------------|---------
Content Library | Add library item                                    | `ContentLibrary.AddLibraryItem`
 ...            | Update Library Item                                 | `ContentLibrary.UpdateLibraryItem`
Datastore       | Allocate space                                      | `Datastore.AllocateSpace`
...             | Browse datastore                                    | `Datastore.Browse`
...             | Low level file operations                           | `Datastore.Browse`
Network         | Assign network                                      | `Network.Assign`
Resource        | Assign virtual machine to resource pool             | `Resource.AssignVMToPool`
vApp            | Export                                              | `vApp.Export`
Virtual Machine | Configuration > Add new disk                        | `VirtualMachine.Config.AddNewDisk`
...             | Configuration > Add or remove device                | `VirtualMachine.Config.AddRemoveDevice`
...             | Configuration > Advanced configuration              | `VirtualMachine.Config.AdvancedConfig`
...             | Configuration > Change CPU count                    | `VirtualMachine.Config.CPUCount`
...             | Configuration > Change memory                       | `VirtualMachine.Config.Memory`
...             | Configuration > Change settings                     | `VirtualMachine.Config.Settings`
...             | Configuration > Change Resource                     | `VirtualMachine.Config.Resource`
...             | Configuration > Set annotation                      | `VirtualMachine.Config.Annotation`
...             | Edit Inventory > Create from existing               | `VirtualMachine.Inventory.CreateFromExisting`
...             | Edit Inventory > Create new                         | `VirtualMachine.Inventory.Create`
...             | Edit Inventory > Remove                             | `VirtualMachine.Inventory.Delete`
...             | Interaction > Configure CD media                    | `VirtualMachine.Interact.SetCDMedia`
...             | Interaction > Configure floppy media                | `VirtualMachine.Interact.SetFloppyMedia`
...             | Interaction > Connect devices                       | `VirtualMachine.Interact.DeviceConnection`
...             | Interaction > Inject USB HID scan codes             | `VirtualMachine.Interact.PutUsbScanCodes`
...             | Interaction > Power off                             | `VirtualMachine.Interact.PowerOff`
...             | Interaction > Power on                              | `VirtualMachine.Interact.PowerOn`
...             | Provisioning > Create template from virtual machine | `VirtualMachine.Provisioning.CreateTemplateFromVM`
...             | Provisioning > Mark as template                     | `VirtualMachine.Provisioning.MarkAsTemplate`
...             | Provisioning > Mark as virtual machine              | `VirtualMachine.Provisioning.MarkAsVM`
...             | State > Create snapshot                             | `VirtualMachine.State.CreateSnapshot`

**Global permissions are required for the content library.** For example:

1. Log in to the vCenter Server at _<management_vcenter_server_fqdn>/ui_ as `administrator@vsphere.local`.
2. Select **Menu** > **Administration**.
3. In the left pane, select **Access control** > **Global permissions** and click the **Add permissions** icon.
4. In the **Add permissions** dialog box, enter the service account (_e.g._ svc-packer-vsphere@rainpole.io), select the custom role (_e.g._ Packer to vSphere Integration Role) and the **Propagate to children** check box, and click OK.

In an environment with many vCenter Server instances, such as management and workload domains, you may wish to further reduce the scope of access across the infrastructure in vSphere for the service account. For example, if you do not want Packer to have access to your management domain, but only allow access to workload domains:

1. From the **Hosts and clusters** inventory, select management domain vCenter Server to restrict scope, and click the **Permissions** tab.
2. Select the service account with the custom role assigned and click the **Change role** icon.
3. In the **Change role** dialog box, from the **Role** drop-down menu, select **No Access**, select the **Propagate to children** check box, and click **OK**.

## Step: Configure Build Variables

The [variables][packer-variables] are defined in `.pkvars.hcl` files.

### **Copy the Example Variables**

Run the config script `./config.sh` to copy the `.pkvars.hcl.example` files to the `config` directory.

> ⚠️ **WARNING**:
> 
> The directory created by config.sh will contain sensitive information relating to your vSphere environment. You **MUST** ensure that the contents of that directory are **_NEVER_** committed or publicly exposed.

While the `config` folder is the default folder, you may override the default by passing an alternate value as the first argument.

```console
./config.sh config/foo
./build.sh config/foo
```

For example, this is useful for the purposes of running machine image builds for different environments.

**San Francisco:** us-west-1

```console
./config.sh config/us-west-1
./build.sh config/us-west-1
```

**Los Angeles:** us-west-2

```console
./config.sh config/us-west-2
./build.sh config/us-west-2
```

#### Build Variables

Edit the `config/build.pkvars.hcl` file to configure the following:

* Credentials for the default account on machine images.

**Example**: `config/build.pkvars.hcl`

```hcl
build_username           = "rainpole"
build_password           = "<plaintext_password>"
build_password_encrypted = "<sha512_encrypted_password>"
build_key                = "<public_key>"
```
You can also override the `build_key` value with contents of a file, if required.

For example:

```hcl
build_key = file("${path.root}/config/ssh/build_id_ecdsa.pub")
```

Generate a SHA-512 encrypted password for the `build_password_encrypted` using tools like mkpasswd.

**Example**: mkpasswd using Docker on macOS:

```console
rainpole@macos>  docker run -it --rm alpine:latestvmwar mkpasswd -m sha512
Password: ***************
[password hash]
```

**Example**: mkpasswd on Linux:

```console
rainpole@linux>  mkpasswd -m sha-512
Password: ***************
[password hash]
```
Generate a public key for the `build_key` for public key authentication.

**Example**: macOS and Linux.

```console
rainpole@macos> cd .ssh/
rainpole@macos ~/.ssh> ssh-keygen -t ecdsa -b 521 -C "code@rainpole.io"
Generating public/private ecdsa key pair.
Enter file in which to save the key (/Users/rainpole/.ssh/id_ecdsa):
Enter passphrase (empty for no passphrase): **************
Enter same passphrase again: **************
Your identification has been saved in /Users/rainpole/.ssh/id_ecdsa.
Your public key has been saved in /Users/rainpole/.ssh/id_ecdsa.pub.
```

The content of the public key, `build_key`, is added the key to the `.ssh/authorized_keys` file of the `build_username` on the guest operating system.

#### Common Variables

Edit the `config/common.pkvars.hcl` file to configure the following common variables:

* Virtual Machine Settings
* Template and Content Library Settings
* Removable Media Settings
* Boot and Provisioning Settings

**Example**: `config/common.pkvars.hcl`

```hcl
// Virtual Machine Settings
common_vm_version           = 19
common_tools_upgrade_policy = true
common_remove_cdrom         = true

// Template and Content Library Settings
common_template_conversion     = false
common_content_library_name    = "sfo-w01-lib01"
common_content_library_ovf     = true
common_content_library_destroy = true

// Removable Media Settings
common_iso_datastore = "sfo-w01-cl01-ds-nfs01"

// Boot and Provisioning Settings
common_data_source      = "http"
common_http_ip          = null
common_http_port_min    = 8000
common_http_port_max    = 8099
common_ip_wait_timeout  = "20m"
common_shutdown_timeout = "15m"
```

#### Data Source Options

`http` is the default provisioning data source for machine image builds.

You can change the `common_data_source` from `http` to `disk` to build supported machine images without the need to use Packer's HTTP server. This is useful for environments that may not be able to route back to the system from which Packer is running.

The `cd_content` option is used when selecting `disk` unless the distribution does not support a secondary CD-ROM. For distributions that do not support a secondary CD-ROM the `floppy_content` option is used.

```hcl
common_data_source = "disk"
```

#### HTTP Binding

If you need to define a specific IPv4 address from your host for Packer's HTTP Server, modify the `common_http_ip` variable from `null` to a `string` value that matches an IP address on your Packer host. For example:

```hcl
common_http_ip = "172.16.11.254"
```

#### Proxy Variables (Optional)

Edit the `config/proxy.pkvars.hcl` file to configure the following:

* SOCKS proxy settings used for connecting to Linux machine images.
* Credentials for the proxy server.

**Example**: `config/proxy.pkvars.hcl`

```hcl
communicator_proxy_host     = "proxy.rainpole.io"
communicator_proxy_port     = 1080
communicator_proxy_username = "rainpole"
communicator_proxy_password = "<plaintext_password>"
```

#### vSphere Variables

Edit the `builds/vsphere.pkvars.hcl` file to configure the following:

* vSphere Endpoint and Credentials
* vSphere Settings

**Example**: `config/vsphere.pkvars.hcl`

```hcl
vsphere_endpoint             = "sfo-w01-vc01.sfo.rainpole.io"
vsphere_username             = "svc-packer-vsphere@rainpole.io"
vsphere_password             = "<plaintext_password>"
vsphere_insecure_connection  = true
vsphere_datacenter           = "sfo-w01-dc01"
vsphere_cluster              = "sfo-w01-cl01"
vsphere_datastore            = "sfo-w01-cl01-ds-vsan01"
vsphere_network              = "sfo-w01-seg-dhcp"
vsphere_folder               = "sfo-w01-fd-templates"
```
#### **Using Environment Variables**

Alternatively, you can set your environment variables if you would prefer not to save sensitive potentially information in cleartext files. You can add these to environmental variables using the included `set-envvars.sh` script:

```console
rainpole@macos> . ./set-envvars.sh
```

> **NOTE**: You need to run the script as source or the shorthand "`.`".

#### **Machine Image Variables**

Edit the `*.auto.pkvars.hcl` file in each `builds/<type>/<build>` folder to configure the following virtual machine hardware settings, as required:

* CPU Sockets `(int)`
* CPU Cores `(int)`
* Memory in MB `(int)`
* Primary Disk in MB `(int)`
* .iso Path `(string)`
* .iso File `(string)`
* .iso Checksum Type `(string)`
* .iso Checksum Value `(string)`

    >**Note**: All `variables.auto.pkvars.hcl` default to using the [VMware Paravirtual SCSI controller][vmware-pvscsi] and the [VMXNET 3][vmware-vmxnet3] network card device types.


### Step 5 - Modify the Configurations (Optional)

If required, modify the configuration files for Microsoft Windows.

#### Microsoft Windows Unattended and Scripts

Variables are passed into the [Microsoft Windowsunattend files (`autounattend.xml`)][microsoft-windows-unattend] as Packer template files (`autounattend.pkrtpl.hcl`) to generate these on-demand. Unattend files are used to automatically configure Windows on initial bootup. This includes setting up user profiles, defining the language and timezone, and many other options that would normally be configured in the Windows UI on initial boot of the OS. 

**Need help customizing the configuration files?**

* **Microsoft Windows** - Use the Microsoft Windows [Answer File Generator][microsoft-windows-afg] if you need to customize the provided examples further.
  * Additionally, refer to the [CloudBase Init documentation][cloud-base-init] on specifics relating to how each VM created from a Windows template is personalized and made unique.   

### Step 6 - Add Certificates

Save a copy of your PEM encoded Root Certificate Authority certificate to the following in `.cer` format.
- `/certificates` for Windows machine images.

These files are copied to the guest operating systems and added the certificate to the Trusted Certificate Authority of the guest operating system. Windows still uses the shell provisioner at this time.

## Build

This repository supports two primary build workflows. Each workflow shares common variables and scripts but targets different Packer builders and post-processors. The content below is consolidated so duplicate instructions have been removed; unique details have been preserved.

### vSphere template build process

Follow these steps to build a vSphere template using the existing files and your configuration.

1. Install prerequisites (see Requirements above)
2. Prepare configuration
   - Copy example variable files into a `config` directory using the included helper:
     - `./config.sh`
   - Edit the files in config/ (build.pkrvars.hcl, common.pkrvars.hcl, and any template-specific .pkrvars.hcl) to match your environment and desired VM settings (ISO path, checksums, build account, SSH keys, etc.).
     - If further build specific configuration is required (such as Windows Server version specific ISO information) edit the `windows-server.auto.pkrvars.hcl` file in the relevant `builds` path (e.g. `builds/windows/server/2025/vagrant/windows-server.auto.pkrvars.hcl`) 
3. Download and verify ISOs
   - Download the Windows ISO(s) you intend to use and record checksum values in the appropriate config file (see the `iso_path`, `iso_file`, `iso_checksum_type` and `iso_checksum_value` variables).

4. Execute the custom build script
   - Make sure the script is executable and run it from the repository root:
     - chmod +x create/build-vsphere.sh
     - ./create/build-vsphere.sh [config]
   - The script is interactive: it presents a menu of available targets (e.g. Windows Server 2025 Datacenter Desktop) — choose the entry you want, optionally enter a custom template prefix, and confirm.
   - The script runs `packer init` and then `packer build` for the selected VirtualBox targets. It assembles the correct `-var-file` arguments from your config folder.

5. Build with Variables Files
   - Example Packer command to build a Windows Server 2025 Datacenter template for vSphere:

```console
packer build -force \
  --only vsphere-iso.windows-server-datacenter \
  -var-file="config/build.pkrvars.hcl" \
  -var-file="config/common.pkrvars.hcl" \
  builds/windows/server/2025/vsphere
```

> **Note**: The first time you run a build, Packer will take longer to complete as it installs the required plugins. Subsequent builds will be faster.

6. Build with Environmental Variables
   - If you prefer not to use variable files, you can set the required variables as environment variables. For example:

```console
export PACKER_VAR_vsphere_username='svc-packer-vsphere@rainpole.io'
export PACKER_VAR_vsphere_password='<plaintext_password>'
export PACKER_VAR_common_iso_datastore='sfo-w01-cl01-ds-nfs01'
export PACKER_VAR_iso_path='iso/linux/photon'
export PACKER_VAR_iso_file='photon-4.0-xxxxxxxxx.iso'
export PACKER_VAR_iso_checksum_type='md5'
export PACKER_VAR_iso_checksum_value='xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
```

> **IMPORTANT**: Ensure sensitive information like passwords are not exposed in your shell history. Consider using a tool like `direnv` to manage environment variables in a secure manner.

7. Content Library Behavior
   - When using the `vsphere-iso` builder, Packer can upload the resulting template to a vSphere Content Library. The following variables control this behavior:
     - `common_content_library_name`: Name of the Content Library to use.
     - `common_content_library_ovf`: Set to `true` to upload as an OVF template.
     - `common_content_library_destroy`: Set to `true` to destroy the temporary VM after template creation.

> **Tip**: Using a Content Library can simplify template management in vSphere, especially when working with multiple vCenter instances or clusters.

8. Role and Privilege Requirements
   - Ensure the service account used by Packer has the necessary privileges in vSphere. Refer to the "Configure Service Account Privileges in vSphere" section for details.

9. Example Packer command for `vsphere-iso`
   - To build a Windows Server 2025 Datacenter template for vSphere using the `vsphere-iso` builder:

```console
packer build -force \
  --only vsphere-iso.windows-server-datacenter \
  -var-file="config/build.pkrvars.hcl" \
  -var-file="config/common.pkrvars.hcl" \
  builds/windows/server/2025/vsphere
```

### Vagrant template build process

This repository includes an automated script to generate Vagrant boxes for Windows Server using Packer:

- Script: create/vagrant-build.sh

Follow these steps to create a Vagrant box (VirtualBox) using the provided script.

1. Install prerequisites (see Requirements above)

2. Prepare configuration
   - Copy example variable files into a `config` directory using the included helper:
     - ./config.sh config
   - Edit the files in config/ (build.pkrvars.hcl, common.pkrvars.hcl, and any template-specific .pkrvars.hcl) to match your environment and desired VM settings (ISO path, checksums, build account, SSH keys, etc.).

3. Download and verify ISOs
   - Download the Windows ISO(s) you intend to use and record checksum values in the appropriate config file (set `iso_path`, `iso_file`, `iso_checksum_type` and `iso_checksum_value`).
   - Alternatively, if you specify an `iso_url` in the `windows-server.auto.pkrvars.hcl` configuration Packer will automatically download and cache the ISO for you.

4. Run the vagrant-build script
   - Make the script executable and run it from the repository root:
     - chmod +x create/vagrant-build.sh
     - ./create/vagrant-build.sh config
   - The script is interactive: it lists available Vagrant targets (e.g., Windows Server 2025 Datacenter Desktop). Choose the entry you want, optionally enter a custom template prefix, and confirm.
   - The script runs `packer init` and then `packer build` for the selected VirtualBox targets and assembles the correct `-var-file` arguments from your config folder.

5. Build artifacts
   - On success, the VirtualBox `*.box` file is produced in the build directory (as configured by the Packer post-processor). The script prints completion information.

6. Add the box to Vagrant and test
   - vagrant box add --name my-windows-box /path/to/windowsXXXX-virtualbox.box
   - Create a simple Vagrantfile and test:
     - vagrant init my-windows-box
     - vagrant up --provider=virtualbox

Alternative (manual) packer command
- If you prefer not to use the interactive script you can run Packer directly. Example to build the Windows Server 2025 Vagrant box:

```console
packer init builds/windows/server/2025/vagrant
packer build -force \
  --only virtualbox-iso.windows-server-datacenter-dexp \
  -var-file="config/build.pkrvars.hcl" \
  -var-file="config/common.pkrvars.hcl" \
  builds/windows/server/2025/vagrant
```

## Troubleshoot

* Read [Debugging Packer Builds][packer-debug].

## Credits
* Owen Reynolds [@OVDamn][credits-owen-reynolds-twitter]

    [VMware Tools for Windows][credits-owen-reynolds-github] installation PowerShell script.

[//]: Links

[cloud-init]: https://cloudinit.readthedocs.io/en/latest/
[credits-owen-reynolds-twitter]: https://twitter.com/OVDamn
[credits-owen-reynolds-github]: https://github.com/getvpro/Build-Packer/blob/master/Scripts/Install-VMTools.ps1
[download-git]: https://git-scm.com/downloads
[gomplate-install]: https://gomplate.ca/
[hashicorp]: https://www.hashicorp.com/
[iso]: https://en.wikipedia.org/wiki/ISO_image
[microsoft-windows-afg]: https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/update-windows-settings-and-scripts-create-your-own-answer-file-sxs?view=windows-11#create-and-modify-an-answer-file
[cloud-base-init]: https://cloudbase-init.readthedocs.io/en/latest/index.html
[microsoft-windows-autologon]: https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-shell-setup-autologon-password-value
[microsoft-windows-unattend]: https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/
[packer]: https://www.packer.io
[packer-debug]: https://www.packer.io/docs/debugging
[packer-install]: https://www.packer.io/intro/getting-started/install.html
[packer-plugin-vsphere]: https://www.packer.io/docs/builders/vsphere/vsphere-iso
[packer-plugin-windows-update]: https://github.com/rgl/packer-plugin-windows-update
[packer-variables]: https://www.packer.io/docs/templates/hcl_templates/variables
[ssh-keygen]:https://www.ssh.com/ssh/keygen/
[terraform-install]: https://www.terraform.io/docs/cli/install/apt.html
[vmware-pvscsi]: https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.hostclient.doc/GUID-7A595885-3EA5-4F18-A6E7-5952BFC341CC.html
[vmware-vmxnet3]: https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.vm_admin.doc/GUID-AF9E24A8-2CFA-447B-AC83-35D563119667.html
[vsphere-api]: https://code.vmware.com/apis/968
[vsphere-content-library]: https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.vm_admin.doc/GUID-254B2CE8-20A8-43F0-90E8-3F6776C2C896.html
[vsphere-guestosid]: https://vdc-download.vmware.com/vmwb-repository/dcr-public/b50dcbbf-051d-4204-a3e7-e1b618c1e384/538cf2ec-b34f-4bae-a332-3820ef9e7773/vim.vm.GuestOsDescriptor.GuestOsIdentifier.html
[vsphere-efi]: https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.security.doc/GUID-898217D4-689D-4EB5-866C-888353FE241C.html
[vsphere-upload]: https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.storage.doc/GUID-58D77EA5-50D9-4A8E-A15A-D7B3ABA11B87.html?hWord=N4IghgNiBcIK4AcIHswBMAEAzAlhApgM4gC+QA
[vsphere-tpm]: https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.vm_admin.doc/GUID-4DBF65A4-4BA0-4667-9725-AE9F047DE00A.html
