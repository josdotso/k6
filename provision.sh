#!/usr/bin/env bash

set -euo pipefail

## Load settings.
source /vagrant/envrc

## Disable systemd-resolved and install resolv.conf.
##
## TODO: Try this instead: https://unix.stackexchange.com/a/358485
##
## This is only necessary to avoid a collision on
## udp/53 between systemd-resolved and LXD's dnsmasq.
sudo systemctl disable systemd-resolved.service
sudo systemctl stop systemd-resolved.service
sudo systemctl mask systemd-resolved.service
sudo cp /etc/resolv.conf /etc/resolv.conf.$$
if [ -e /vagrant/resolv.conf.vagrant-custom ]; then
  resolvconf=/vagrant/resolv.conf.vagrant-custom
else
  resolvconf=/vagrant/resolv.conf.vagrant
fi
sudo cp -f "${resolvconf}" /etc/resolv.conf

## Upgrade apt cache.
sudo apt update

## Install tools.
sudo apt install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  dnsutils \
  linux-headers-$(uname -r) \
  linux-modules-$(uname -r) \
  lxd \
  lxd-client \
  nmap \
  software-properties-common \
  vim

## If first boot...
if [ ! -e /var/lib/provisioned ]; then

  ## Install kubeadm, kubectl.
  sudo curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
## We say "kubernetes-xenial" here because
## "kubernetes-bionic" is 404.
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
  sudo apt update
  sudo apt install -y kubeadm kubectl
  sudo apt-mark hold kubeadm kubectl

  ## Disable swap (required for kubelet)
  sudo sed -i '/swap/d' /etc/fstab
  sudo swapoff -a

  ## Ensure br_netfilter kernel module
  ## is loaded on every reboot.
  echo br_netfilter | sudo tee /etc/modules-load.d/br_netfilter.conf
  sudo systemctl daemon-reload
  sudo systemctl restart systemd-modules-load.service
  lsmod | grep br_netfilter

  ## Confirm bridge-nf-call-ip(6)tables proc values.
  ## ref: https://github.com/corneliusweig/kubernetes-lxd
  grep '^1$' /proc/sys/net/bridge/bridge-nf-call-iptables
  grep '^1$' /proc/sys/net/bridge/bridge-nf-call-ip6tables

  ## Initialize LXD.
  cat /vagrant/lxd.yaml | sudo lxd init --preseed

  ## Add ubuntu-minimal LXD remote.
  lxc remote add --protocol simplestreams \
    ubuntu-minimal https://mirrors.servercentral.com/ubuntu-cloud-images/minimal/releases/

  ## Fetch and export image.
  if [ -e /vagrant/tmp/ubuntu-18.04-minimal-cloudimg-amd64-lxd.tar.xz ]; then
    ## Eagerly import the cached image. Tolerate failure.
    lxc image import \
      /vagrant/tmp/ubuntu-18.04-minimal-cloudimg-amd64-lxd.tar.xz \
      /vagrant/tmp/ubuntu-18.04-minimal-cloudimg-amd64.squashfs \
        --alias ubuntu-minimal:18.04 || true
  else
    mkdir -p /vagrant/tmp
    lxc image export ubuntu-minimal:18.04 /vagrant/tmp
  fi

  ## Create subuid and subgid files.
  ## ref: https://github.com/corneliusweig/kubernetes-lxd
  cat <<EOF | sudo tee /etc/subuid
root:1000000:1000000000
$(whoami):1000000:1000000000
EOF
  sudo cp -f /etc/subuid /etc/subgid

  ## Install Docker for IPv6.
  if ! getent group docker; then
    sudo groupadd docker
  fi
  if getent passwd vagrant; then
    sudo usermod -aG docker vagrant
  fi
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  sudo apt update
  sudo mkdir /etc/docker
  sudo mkdir -p /etc/systemd/system/docker.service.d
  cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=cgroupfs"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "ipv6": true,
  "fixed-cidr-v6": "2001:db8:1::/64"
}
EOF
  sudo apt install -y docker-ce

  ## Initialize NAT64.
  sudo curl -fsSL https://raw.githubusercontent.com/josdotso/docker-jool/master/jool.service \
    -o /etc/systemd/system/jool.service
  sudo systemctl daemon-reload
  sudo systemctl enable jool.service
  sudo systemctl start jool.service

  ## Give it some time.
  sleep 45

  sudo touch /var/lib/provisioned
fi

## Launch LXD container for masters
for n in $(seq ${NUM_MASTERS}); do
  if ! lxc exec master${n} true; then
    lxc launch --profile init ubuntu-minimal:18.04 master${n}
    sleep 10  # Give it some time to boot.
    lxc exec master${n} /vagrant/kubernetes/provision.sh
  fi
done

## Give the user a copy of the kubeconfig
export ADMIN_KUBECONFIG=/vagrant/admin.conf
export KUBECONFIG=~/.kube/config
mkdir -p $(dirname ${KUBECONFIG})
touch ${KUBECONFIG}
chmod 0600 ${KUBECONFIG}
sudo cat ${ADMIN_KUBECONFIG} > ${KUBECONFIG}

## Launch LXD container for nodes
if (( ${NUM_NODES} > 0 )); then
  for n in $(seq ${NUM_NODES}); do
    if ! lxc exec node${n} true; then
      lxc launch --profile join ubuntu-minimal:18.04 node${n}
      sleep 10  # Give it some time to boot.
      lxc exec node${n} /vagrant/kubernetes/provision.sh
      kubectl label node node${n} kubernetes.io/role=node

      ## Check status after node join.
      kubectl get nodes -o wide
      kubectl get pods  -o wide --all-namespaces
    fi
  done
fi

## Check final status.
kubectl get nodes -o wide
kubectl get pods  -o wide --all-namespaces

## Report general success.
echo OK
