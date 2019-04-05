.PHONY: reset

osx_deps:
	vagrant plugin install vagrant-cachier
	vagrant plugin install vagrant-proxyconf

reset:
	vagrant destroy && vagrant up
