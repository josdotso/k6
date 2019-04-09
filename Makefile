.PHONY: reset
reset:
	vagrant destroy && vagrant up

.PHONY: osx_deps
osx_deps:
	vagrant plugin install vagrant-cachier
	vagrant plugin install vagrant-proxyconf
