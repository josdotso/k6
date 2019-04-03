# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.box = "bento/ubuntu-18.04"

  config.vm.network "public_network",
    bridge: [  # Vagrant falls back to first match.
      "en8: Belkin USB-C LAN"
    ]

  config.vm.provider "virtualbox" do |vb|
    vb.cpus = "2"
    vb.memory = "2048"
  end

  config.vm.provision "shell",
    path: "provision.sh",
    privileged: false

end
