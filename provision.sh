#!/usr/bin/env bash

set -euo pipefail

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

## Disable swap (required for kubelet)
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

## Create subuid and subgid files.
## ref: https://github.com/corneliusweig/kubernetes-lxd
cat <<EOF | sudo tee /etc/subuid
root:1000000:1000000000
$(whoami):1000000:1000000000
EOF
sudo cp -f /etc/subuid /etc/subgid

## Install Docker for IPv6.
sudo groupadd docker
if getent passwd vagrant; then
  sudo usermod -aG docker vagrant
fi
if getent passwd ubuntu; then
  sudo usermod -aG docker ubuntu
fi
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y docker-ce
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "ipv6": true,
  "fixed-cidr-v6": "2001:db8:1::/64"
}
EOF
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo systemctl daemon-reload
sudo systemctl restart docker

## Disable systemd-resolved and install resolv.conf.
##
## TODO: Try this instead: https://unix.stackexchange.com/a/358485
##
## This is only necessary to avoid a collision on
## udp/53 between systemd-resolved and docker-bind64.
sudo systemctl disable systemd-resolved.service
sudo systemctl stop systemd-resolved.service
sudo cp /etc/resolv.conf /etc/resolv.conf.$$
if [ -e /vagrant/resolv.conf.custom ]; then
  resolvconf=/vagrant/resolv.conf.custom
else
  resolvconf=/vagrant/resolv.conf
fi
sudo cp -f "${resolvconf}" /etc/resolv.conf

## Install and start docker-bind64.
sudo curl -fsSL https://raw.githubusercontent.com/josdotso/docker-bind64/master/bind64.service \
  -o /etc/systemd/system/bind64.service
sudo sed -i 's@53:@1053:@g' /etc/systemd/system/bind64.service  ## resolve port conflict with LXD dnsmasq
sudo systemctl daemon-reload
sudo systemctl enable bind64.service
sudo systemctl start bind64.service
sleep 20  # Give it a little time to pull image and start.
sudo systemctl status bind64

## Install and start docker-jool.
sudo curl -fsSL https://raw.githubusercontent.com/josdotso/docker-jool/master/jool.service \
  -o /etc/systemd/system/jool.service
sudo systemctl daemon-reload
sudo systemctl enable jool.service
sudo systemctl start jool.service
sleep 20  # Give it a little time to pull image and start.
sudo systemctl status jool

## Initialize LXD with Preseed YAML heredoc.
cat /vagrant/lxd.yaml | sudo lxd init --preseed

## Add ubuntu-minimal LXD remote.
lxc remote add --protocol simplestreams ubuntu-minimal https://mirrors.servercentral.com/ubuntu-cloud-images/minimal/releases/

## Launch LXD container for Kubernetes Master #1: "master1"
lxc launch --profile master1 ubuntu-minimal:18.04 master1

## Report that it kind of worked.
echo OK
