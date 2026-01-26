Vagrant.configure("2") do |config|
  config.vm.box = "windows2025-virtualbox.box"
  config.vm.communicator = "winrm"
  config.winrm.username = "$BUILD_USERNAME"
  config.winrm.password = "$BUILD_PASSWORD"

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
    lv.graphics_type = "vnc"
    lv.graphics_ip = "0.0.0.0"
    lv.graphics_port = 5900
    lv.graphics_password = "$BUILD_PASSWORD"
  end
end
