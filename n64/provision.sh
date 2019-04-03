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
  nmap \
  software-properties-common \
  vim

## Install Docker for IPv6.
groupadd docker
if getent passwd vagrant; then
  usermod -aG docker vagrant
fi
if getent passwd ubuntu; then
  usermod -aG docker ubuntu
fi
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update
apt install -y docker-ce
cat > /etc/docker/daemon.json <<EOF
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
mkdir -p /etc/systemd/system/docker.service.d
systemctl daemon-reload
systemctl restart docker

## Disable systemd-resolved and install resolv.conf.
##
## This is only necessary to avoid a collision on
## udp/53 between systemd-resolved and docker-bind64.
systemctl disable systemd-resolved.service
systemctl stop systemd-resolved.service
cp /etc/resolv.conf /etc/resolv.conf.$$
if [ -e /vagrant/n64/resolv.conf.custom ]; then
  resolvconf=/vagrant/n64/resolv.conf.custom
else
  resolvconf=/vagrant/n64/resolv.conf
fi
cp -f "${resolvconf}" /etc/resolv.conf

## Install and start docker-bind64.
curl -fsSL https://raw.githubusercontent.com/josdotso/docker-bind64/master/bind64.service \
  -o /etc/systemd/system/bind64.service
systemctl daemon-reload
systemctl enable bind64.service
systemctl start bind64.service
sleep 20  # Give it a little time to pull image and start.
systemctl status bind64

## Install and start docker-jool.
curl -fsSL https://raw.githubusercontent.com/josdotso/docker-jool/master/jool.service \
  -o /etc/systemd/system/jool.service
systemctl daemon-reload
systemctl enable jool.service
systemctl start jool.service
sleep 20  # Give it a little time to pull image and start.
systemctl status jool

## Report that it kind of worked.
echo OK
