Vagrant.configure("2") do |config|
  config.vm.box = "windows2025-virtualbox.box"
  config.vm.communicator = "winrm"
  config.winrm.username = "$BUILD_USERNAME"
  config.winrm.password = "$BUILD_PASSWORD"
  config.winrm.transport = :plaintext
  config.winrm.basic_auth_only = true

  config.vm.provider "virtualbox" do |vb|
    vb.memory = 4096
    vb.cpus = 4
    vb.customize ["modifyvm", :id, "--vrde", "on"]
    vb.customize ["modifyvm", :id, "--vrdeport", "3390"]
    vb.customize ["modifyvm", :id, "--vrdeaddress", "0.0.0.0"]
    vb.customize ["modifyvm", :id, "--vram", "128"]
    vb.customize ["setextradata", :id, "CustomVideoMode1", "1920x1080x32"]
  end

  config.vm.provider "libvirt" do |lv|
    lv.memory = 4096
    lv.cpus = 4
    lv.driver = "kvm"
    lv.machine_type = "pc"
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
end
