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

## Configure a host mount copy of KUBECONFIG
## to work with vagrant port forwarding.
sudo cat ${KUBECONFIG} \
  | sed 's@server: .*@server: "https://127.0.0.1:6443"@g' \
  > /vagrant/admin.conf

## Report that it kind of worked.
echo OK
