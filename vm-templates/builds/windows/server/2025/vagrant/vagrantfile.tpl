Vagrant.configure("2") do |config|
  # NOTE: Do not set config.vm.box here. The box name is chosen by the
  # consumer at `vagrant box add` / `vagrant init` time. Setting it inside a
  # packaged box's Vagrantfile is ignored at best and confusing at worst.
  #
  # Credentials are hardcoded (not $VARs). The Packer vagrant post-processor
  # renders this file with Go text/template, NOT envsubst, so shell-style
  # "$BUILD_USERNAME" placeholders would be copied in literally and break WinRM.
  config.vm.communicator = "winrm"
  config.winrm.username = "vagrant"
  config.winrm.password = "vagrant"
  config.winrm.transport = :plaintext
  config.winrm.basic_auth_only = true

  config.vm.provider "libvirt" do |lv|
    lv.memory = 4096
    lv.cpus = 4
    lv.driver = "kvm"
    lv.machine_type = "pc"
    # The image is built on IDE + e1000, then VirtIO drivers are staged by
    # scripts/windows/windows-qemu-tools.ps1. If `vagrant up` bluescreens with
    # INACCESSIBLE_BOOT_DEVICE (0x7B), viostor did not register as a boot
    # driver -- fall back to `lv.disk_bus = "ide"` to confirm, then fix the
    # driver injection (see the scratch-disk note from the build discussion).
    lv.disk_bus = "virtio"
    lv.nic_model_type = "virtio"
    lv.graphics_type = "vnc"
    lv.graphics_ip = "0.0.0.0"
    lv.graphics_port = -1
    lv.video_type = "qxl"
    lv.video_vram = 65536
    lv.management_network_mode = "nat"
    lv.channel :type => 'unix', :target_name => 'org.qemu.guest_agent.0', :target_type => 'virtio'
  end

  config.vm.provider "virtualbox" do |vb|
    vb.memory = 4096
    vb.cpus = 4
    vb.customize ["modifyvm", :id, "--vrde", "on"]
    vb.customize ["modifyvm", :id, "--vrdeport", "3390"]
    vb.customize ["modifyvm", :id, "--vrdeaddress", "0.0.0.0"]
    vb.customize ["modifyvm", :id, "--vram", "128"]
    vb.customize ["setextradata", :id, "CustomVideoMode1", "1920x1080x32"]
  end
end
