/*
    DESCRIPTION:
    Microsoft Windows Server 2025 template for VirtualBox and QEMU, outputting as a Vagrant box.
*/

packer {
  required_version = ">= 1.8.0"
  required_plugins {
    virtualbox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/virtualbox"
    }
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
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

locals {
  build_by      = "Built by: HashiCorp Packer ${packer.version}"
  build_date    = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  build_version = formatdate("YY.MM", timestamp())
  manifest_date = formatdate("YYYY-MM-DD hh:mm:ss", timestamp())
  manifest_path = "${path.cwd}/manifests/"
  custom_prefix = var.custom_template_prefix == "" ? "" : "${var.custom_template_prefix}-"
}

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
  // installed by scripts/windows/windows-vagrant-vmtools.ps1
  guest_additions_path = "C:\\Users\\VBoxGuestAdditions.iso"

  cd_content = {
    "autounattend.xml" = templatefile("${abspath(path.root)}/data/autounattend.pkrtpl.hcl", {
      vm_virtualization_platform = "virtualbox"
      build_username       = var.vagrant_username
      build_password       = var.vagrant_password
      vm_inst_os_language  = var.vm_inst_os_language
      vm_inst_os_keyboard  = var.vm_inst_os_keyboard
      vm_inst_os_image     = var.vm_inst_os_image_datacenter_desktop_index
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

source "qemu" "windows-server-datacenter-dexp" {
  /*
    QEMU/KVM source for Windows Server 2025 on Ubuntu 24.04 with nested virtualization.

    This configuration uses IDE disk and e1000 network for maximum compatibility.
    These devices are natively supported by Windows PE without additional drivers.

    Prerequisites on Ubuntu 24.04:
      sudo apt-get update
      sudo apt-get install -y qemu-kvm qemu-system-x86 qemu-utils libvirt-daemon-system \
                              libvirt-clients virtinst bridge-utils
      sudo usermod -aG kvm,libvirt $USER
      # Log out and back in, then verify KVM is available:
      ls -la /dev/kvm
  */

  // Accelerator: Use KVM for nested virtualization in vSphere VM
  accelerator = "kvm"

  // Machine type: Use standard PC (i440FX) for IDE CD-ROM compatibility
  machine_type = "pc"

  // CPU: Use host passthrough for best performance with nested virt
  cpu_model = "host"

  // ISO Settings - Windows Server 2025 installation media
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum_value

  // Disk Configuration - Use IDE for maximum compatibility during install
  // VirtIO disk requires drivers loaded first, which creates chicken-egg problem
  // We'll use IDE for install, then can convert to virtio later if needed
  disk_interface     = "ide"
  disk_size          = "${var.vm_disk_size}M"
  disk_cache         = "writeback"
  format             = "qcow2"

  // CPU and Memory
  cpus   = var.vm_cpu_sockets
  memory = var.vm_mem_size

  // Network: Use e1000 for compatibility (doesn't require drivers)
  // Can be changed to virtio-net after drivers are installed
  net_device = "e1000"

  // WinRM Communication
  communicator   = "winrm"
  winrm_username = var.vagrant_username
  winrm_password = var.vagrant_password
  winrm_port     = var.communicator_port
  winrm_timeout  = var.communicator_timeout

  // Display: VNC for debugging
  headless         = var.qemu_headless
  vnc_bind_address = "0.0.0.0"
  vnc_port_min     = 5900
  vnc_port_max     = 5920

  // Output settings
  vm_name          = "${local.custom_prefix}windows2025-vagrant-qemu"
  output_directory = "${path.cwd}/output-qemu"

  // QEMU additional arguments - minimal to avoid conflicts with Packer's defaults
  qemuargs = [
    // CPU configuration for nested virt
    ["-cpu", "host"],

    // RTC settings to prevent time drift
    ["-rtc", "base=localtime,clock=host"],

    // USB controller for input
    ["-device", "qemu-xhci"]
  ]

  // Packer-generated CD with autounattend.xml and scripts
  // This will be the second CD-ROM after the Windows ISO
  cd_content = {
    "autounattend.xml" = templatefile("${abspath(path.root)}/data/autounattend.pkrtpl.hcl", {
      vm_virtualization_platform = "qemu"
      build_username       = var.vagrant_username
      build_password       = var.vagrant_password
      vm_inst_os_language  = var.vm_inst_os_language
      vm_inst_os_keyboard  = var.vm_inst_os_keyboard
      vm_inst_os_image     = var.vm_inst_os_image_datacenter_desktop_index
      vm_guest_os_timezone = var.vm_guest_os_timezone
    })
  }

  cd_files = [
    "${path.cwd}/scripts/${var.vm_guest_os_family}/"
  ]

  // Boot settings - use boot_key_interval to slow down key presses
  boot_wait         = var.qemu_boot_wait
  boot_command      = var.vm_boot_command
  boot_key_interval = "50ms"

  // Shutdown
  shutdown_timeout = var.common_shutdown_timeout
  shutdown_command = var.vm_shutdown_command
}

build {
  sources = [
    "source.virtualbox-iso.windows-server-datacenter-dexp",
    "source.qemu.windows-server-datacenter-dexp"
  ]

  provisioner "windows-update" {
    search_criteria = "IsInstalled=0"
    filters = [
      "exclude:$_.Title -like '*Preview*'",
      "include:$true",
    ]
  }

  provisioner "powershell" {
    environment_vars = [
      "BUILD_USERNAME=${var.vagrant_username}",
      "PROVIDER={{.Provider}}"
    ]
    elevated_user     = var.vagrant_username
    elevated_password = var.vagrant_password
    scripts           = formatlist("${path.cwd}/%s", var.preparationScripts)
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

  // Generate Vagrantfile BEFORE shutdown (must run while VM is still up)
  provisioner "shell-local" {
    environment_vars = [
      "BUILD_USERNAME=${var.vagrant_username}",
      "BUILD_PASSWORD=${var.vagrant_password}"
    ]
    inline = [
      "envsubst < ${abspath(path.root)}/vagrantfile.tpl > ${abspath(path.root)}/Vagrantfile.pkg"
    ]
  }

  // Run sysprep and shutdown via script - this MUST be the last provisioner
  // because sysprep will shutdown the VM
  provisioner "powershell" {
    elevated_user     = var.vagrant_username
    elevated_password = var.vagrant_password
    script            = "${path.cwd}/scripts/windows/windows-shutdown.ps1"
  }

  post-processor "vagrant" {
    keep_input_artifact = true
    output = "output/windows2025-{{.Provider}}.box"
    vagrantfile_template = "${abspath(path.root)}/Vagrantfile.pkg"
  }

  post-processor "shell-local" {
    inline = ["rm ${abspath(path.root)}/Vagrantfile.pkg"]
  }
}