# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  # Install plugins.
#  required_plugins = %w( vagrant-cachier, vagrant-proxyconf, vagrant-disksize )
#  _retry = false
#  required_plugins.each do |plugin|
#    unless Vagrant.has_plugin? plugin
#      system "vagrant plugin install #{plugin}"
#      _retry=true
#    end
#  end
#  if (_retry)
#    exec "vagrant " + ARGV.join(' ')
#  end

  config.vm.box = "bento/ubuntu-18.04"

  config.vm.network "public_network",
    bridge: [  # Vagrant falls back to first match.
      "en8: Belkin USB-C LAN"
    ]

  config.vm.provider "virtualbox" do |vb|
    vb.cpus = "2"
    vb.memory = "2048"

    ## Enable promiscuous mode on NICs to permit macvlan bridges.
    #vb.customize ["modifyvm", :id, "--nicpromisc1", "allow-all"]
    #vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
  end

  config.vm.provision "shell",
    path: "provision.sh",
    privileged: false

end
