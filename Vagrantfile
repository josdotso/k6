# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.box = "bento/ubuntu-18.04"

  config.vm.network "forwarded_port",
    guest: 6443,
    host: 6443,
    host_ip: "127.0.0.1"

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

  if Vagrant.has_plugin?("vagrant-cachier")
    # Copy/Paste from: https://github.com/fgrehm/vagrant-cachier#quick-start
    #
    # Configure cached packages to be shared between instances of the same base box.
    # More info on http://fgrehm.viewdocs.io/vagrant-cachier/usage
    config.cache.scope = :box

    # For more information please check http://docs.vagrantup.com/v2/synced-folders/basic_usage.html
  end
end
