/*
    DESCRIPTION:
    Microsoft Windows Server 2025 template for VirtualBox, outputting as a Vagrant box.
    Mature packer definition with customization, provisioning, and post-processing.
*/

//  BLOCK: packer
//  The Packer configuration.

packer {
  required_version = ">= 1.8.0"
  required_plugins {
    virtualbox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/virtualbox"
    }
    vagrant = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/vagrant"
    }
    windows-update = {
      version = ">= 0.17.0"
      source  = "github.com/rgl/windows-update"
    }
  }
}

//  BLOCK: locals
//  Defines the local variables.

locals {
  build_by      = "Built by: HashiCorp Packer ${packer.version}"
  build_date    = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  build_version = formatdate("YY.MM", timestamp())
  manifest_date = formatdate("YYYY-MM-DD hh:mm:ss", timestamp())
  manifest_path = "${path.cwd}/manifests/"
  custom_prefix = var.custom_template_prefix == "" ? "" : "${var.custom_template_prefix}-"
}

//  BLOCK: source
//  Defines the builder configuration blocks.
source "virtualbox-iso" "windows-server-datacenter-dexp" {
  guest_os_type          = "Windows2022_64"
  iso_url                = var.iso_url
  iso_checksum           = var.iso_checksum_value

  communicator           = "winrm"
  winrm_username         = var.build_username
  winrm_password         = var.build_password
  winrm_port             = var.communicator_port
  winrm_timeout          = var.communicator_timeout

  vm_name                = "${local.custom_prefix}windows2025-vagrant"
  cpus                   = var.vm_cpu_sockets
  memory                 = var.vm_mem_size
  disk_size              = var.vm_disk_size

  cd_content = {
    "autounattend.xml" = templatefile("${abspath(path.root)}/data/autounattend.pkrtpl.hcl", {
      build_username       = var.build_username
      build_password       = var.build_password
      vm_inst_os_language  = var.vm_inst_os_language
      vm_inst_os_keyboard  = var.vm_inst_os_keyboard
      vm_inst_os_image     = var.vm_inst_os_image_datacenter_desktop_index
      vm_inst_os_kms_key   = var.vm_inst_os_kms_key_datacenter
      vm_guest_os_language = var.vm_guest_os_language
      vm_guest_os_keyboard = var.vm_guest_os_keyboard
      vm_guest_os_timezone = var.vm_guest_os_timezone
    })
  }

  # floppy_files           = [
  #   "setup/install-vagrant-ssh-key.ps1",
  #   "setup/enable-winrm.ps1",
  #   "setup/cleanup.ps1",
  #
  # ]

  boot_wait              = var.vm_boot_wait
  boot_command           = var.vm_boot_command

  shutdown_command       = var.vm_shutdown_command
}

build {
  sources = [
    "source.virtualbox-iso.windows2025"
  ]

  provisioner "windows-update" {
    search_criteria = "IsInstalled=0"
    update_limit    = 40
  }
  #
  # provisioner "powershell" {
  #   scripts = [
  #     "setup/enable-winrm.ps1",
  #     "setup/install-vagrant-ssh-key.ps1",
  #     "setup/install-guest-additions.ps1",
  #     "setup/cleanup.ps1"
  #   ]
  # }

  post-processor "vagrant" {
    keep_input_artifact = false
    output = "${local.custom_prefix}windows2025-virtualbox.box"
    vagrantfile_template = "Vagrantfile.tpl"
  }
}