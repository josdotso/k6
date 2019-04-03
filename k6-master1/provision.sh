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

## Report that it kind of worked.
echo OK
