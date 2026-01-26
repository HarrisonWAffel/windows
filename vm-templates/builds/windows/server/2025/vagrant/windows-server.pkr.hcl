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
  iso_interface = var.vm_cdrom_type
  vboxmanage = [
    [ "modifyvm", "{{.Name}}", "--firmware", var.vm_firmware ],
  ]
  gfx_efi_resolution     = "1680x1050"

  communicator           = "winrm"
  winrm_username         = var.vagrant_username
  winrm_password         = var.vagrant_password
  winrm_port             = var.communicator_port
  winrm_timeout          = var.communicator_timeout

  vm_name                = "${local.custom_prefix}windows2025-vagrant"
  cpus                   = var.vm_cpu_sockets
  memory                 = var.vm_mem_size
  disk_size              = var.vm_disk_size

  headless               = true
  vrdp_bind_address      = "0.0.0.0"

  cd_content = {
    "autounattend.xml" = templatefile("${abspath(path.root)}/data/autounattend.pkrtpl.hcl", {
      build_username       = var.vagrant_username
      build_password       = var.vagrant_password
      vm_inst_os_language  = var.vm_inst_os_language
      vm_inst_os_keyboard  = var.vm_inst_os_keyboard
      vm_inst_os_image     = var.vm_inst_os_image_datacenter_desktop_index
      vm_inst_os_kms_key   = var.vm_inst_os_kms_key_datacenter
      vm_guest_os_language = var.vm_guest_os_language
      vm_guest_os_keyboard = var.vm_guest_os_keyboard
      vm_guest_os_timezone = var.vm_guest_os_timezone
    })
  }

  cd_files = [
    "${path.cwd}/scripts/${var.vm_guest_os_family}/",
  ]

  // Boot and Provisioning Settings
  shutdown_timeout = var.common_shutdown_timeout

  boot_wait              = var.vm_boot_wait
  boot_command           = var.vm_boot_command

  shutdown_command       = var.vm_shutdown_command
}

build {
  sources = [
    "source.virtualbox-iso.windows-server-datacenter-dexp"
  ]

  provisioner "windows-update" {
    search_criteria = "IsInstalled=0"
    filters = [
      "exclude:$_.Title -like '*Preview*'",
      "include:$true",
    ]
  }

  provisioner "windows-restart" {
    pause_before          = "10s"
    restart_check_command = "powershell -command \"& {Write-Output 'restarted.'}\""
    restart_timeout       = "10m"
    max_retries           = 6
  }

  provisioner "powershell" {
    environment_vars = [
      "BUILD_USERNAME=${var.vagrant_username}"
    ]
    elevated_user     = var.vagrant_username
    elevated_password = var.vagrant_password
    scripts           = formatlist("${path.cwd}/%s", var.preparationScripts)
  }

  provisioner "windows-restart" {
    pause_before = "30s"
    restart_check_command = "powershell -command \"& {Write-Output 'restarted.'}\""
    restart_timeout       = "10m"
    max_retries           = 6
  }

  provisioner "file" {
    // This file differs from the initial unattend.xml. This is responsible for
    // user setup (OOBE), but not disk partitions or OS installation. Including fields
    // that have already been set in the original unattend file may break sysprep.
    content      = templatefile("${abspath(path.root)}/data/sysprep_unattend.pkrtpl.hcl", {
      build_username       = var.vagrant_username
      build_password       = var.vagrant_password
      vm_inst_os_keyboard  = var.vm_inst_os_keyboard
      vm_inst_os_language  = var.vm_inst_os_language
      vm_inst_os_keyboard  = var.vm_inst_os_keyboard
      vm_guest_os_timezone = var.vm_guest_os_timezone
    })
    destination = "C:\\autounattend.xml"
  }

  provisioner "shell-local" {
    environment_vars = [
      "BUILD_USERNAME=${var.vagrant_username}",
      "BUILD_PASSWORD=${var.vagrant_password}"
    ]
    inline = [
      "envsubst < ${abspath(path.root)}/vagrantfile.tpl > ${abspath(path.root)}/Vagrantfile.pkg"
    ]
  }

  post-processor "vagrant" {
    keep_input_artifact = true
    output = "output/windows2025-virtualbox.box"
    vagrantfile_template = "${abspath(path.root)}/Vagrantfile.pkg"
  }

  post-processor "shell-local" {
    inline = ["rm ${abspath(path.root)}/Vagrantfile.pkg"]
  }
}