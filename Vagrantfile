# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  if ENV["VAGRANT_DEFAULT_PROVIDER"] == "parallels"
    config.vm.box = "parallels/boot2docker"
    config.vm.network "private_network", type: "dhcp"
  else
    config.vm.box = "yungsang/boot2docker"
    config.vm.network "private_network", ip: ENV["DOCKER_IP"]
  end

  config.vm.network "forwarded_port", guest: 9292, host: 9292, auto_correct: true

  config.vm.synced_folder ".", "/app", type: "nfs"
end
