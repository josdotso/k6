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

## Retry dig until DNS64 comes up.
##
## Then, preheat DNS cache to
## avoid timeouts later.
for h in dl.k8s.io packages.cloud.google.com download.docker.com security.ubuntu.com; do
  echo "Retrying until works: $ dig ${h} AAAA"
  while ! dig ${h} AAAA; do
    printf ""
  done
done

## Retry curl until NAT64 comes up.
for h in dl.k8s.io packages.cloud.google.com download.docker.com security.ubuntu.com; do
  echo "Retrying until works: $ curl ${h}"
  while ! curl -6 -vsL -o /dev/null http://${h}; do
    sleep 2
  done
done

## Install Docker for IPv6.
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
if getent passwd vagrant; then
  sudo usermod -aG docker vagrant
fi
if getent passwd ubuntu; then
  sudo usermod -aG docker ubuntu
fi

## Remove docker0 bridge becuase Kubernetes doesn't
## require it and the IPv4 address on it will confuse
## Kubernetes anyway.
#sudo /vagrant/scripts/remove-docker0.sh

## Install kubelet, kubeadm, kubectl.
sudo curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
## We say "kubernetes-xenial" here because
## "kubernetes-bionic" is 404.
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

## Remove IPv4 address on docker0
sudo ip addr del 172.17.0.1/16 dev docker0

## FYI: Run kubeadm init out of band for now.

## Report that it kind of worked.
echo OK
