# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "yungsang/boot2docker"

  config.vm.network "private_network", ip: ENV["DOCKER_IP"]
  config.vm.network "forwarded_port", guest: 3000, host: 3000, auto_correct: true

  config.vm.synced_folder ".", "/app", type: "nfs"
end
