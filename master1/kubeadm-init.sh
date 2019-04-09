#!/usr/bin/env bash

set -euo pipefail

## Configure preflight errors to ignore.
##
## ref: https://github.com/corneliusweig/kubernetes-lxd#installing-kubernetes-in-the-lxc-container
IGNORED_PREFLIGHT_ERRORS=FileContent--proc-sys-net-bridge-bridge-nf-call-iptables,FileContent--proc-sys-net-bridge-bridge-nf-call-ip6tables

## Preheat Docker image cache.
sudo kubeadm config images pull \
  --config=/vagrant/master1/kubeadm.yaml

## Preemptively symlink to KUBECONFIG.
## (Doing this preemptively because kubeadm might
##  crash the script before we get a chance.)
export KUBECONFIG=/etc/kubernetes/admin.conf
if [ ! -L ~/.kube/config ] && [ ! -e ~/.kube/config ]; then
  mkdir -p ~/.kube
  ln -s ${KUBECONFIG} ~/.kube/config
fi

## Run kubeadm.
sudo kubeadm init \
  --config=/vagrant/master1/kubeadm.yaml \
  --ignore-preflight-errors=${IGNORED_PREFLIGHT_ERRORS}

## Copy KUBECONFIG to host mount.
cp -f ${KUBECONFIG} /vagrant/


#######

#cat << EOT > /etc/cni/net.d/10-bridge-v6.conf
#{
#  "cniVersion": "0.3.0",
#  "name": "mynet",
#  "type": "bridge",
#  "bridge": "cbr0",
#  "isDefaultGateway": true,
#  "ipMasq": true,
#  "hairpinMode": true,
#  "ipam": {
#    "type": "host-local",
#    "ranges": [
#      [
#        {
#          "subnet": "fd2e:236d:b96f:b9d1::/64",
#          "gateway": "fd2e:236d:b96f:b9d1::1"
#        }
#      ]
#    ]
#  }
#}
#EOT

## Install calico for IPv6.



## Report that it kind of worked.
echo OK
