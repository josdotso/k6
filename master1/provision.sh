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

## Retry until DNS64 comes up.
##
## Then, preheat DNS cache to
## avoid timeouts later.
for h in dl.k8s.io download.docker.com; do
  echo "Retrying until works: $ dig ${h} AAAA"
  while ! dig ${h} AAAA; do
    printf "."
  done
done

## Install Docker for IPv6.
getent group docker || groupadd docker
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

## Install kubelet, kubeadm, kubectl.
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
## We say "kubernetes-xenial" here because
## "kubernetes-bionic" is 404.
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

## Preheat Docker image cache.
kubeadm config images pull

## Configure preflight errors to ignore.
##
## ref: https://github.com/corneliusweig/kubernetes-lxd#installing-kubernetes-in-the-lxc-container
IGNORED_PREFLIGHT_ERRORS=FileContent--proc-sys-net-bridge-bridge-nf-call-iptables,FileContent--proc-sys-net-bridge-bridge-nf-call-ip6tables

## Run kubeadm.
kubeadm init \
  --config=/vagrant/master1/kubeadm.conf \
  --ignore-preflight-errors=${IGNORED_PREFLIGHT_ERRORS}

## Copy KUBECONFIG to shared mount.
export KUBECONFIG=/etc/kubernetes/admin.conf
cp -f ${KUBECONFIG} /vagrant/

cat << EOT > /etc/cni/net.d/10-bridge-v6.conf
{
  "cniVersion": "0.3.0",
  "name": "mynet",
  "type": "bridge",
  "bridge": "cbr0",
  "isDefaultGateway": true,
  "ipMasq": true,
  "hairpinMode": true,
  "ipam": {
    "type": "host-local",
    "ranges": [
      [
        {
          "subnet": "fd2e:236d:b96f:b9d1::/64",
          "gateway": "fd2e:236d:b96f:b9d1::1"
        }
      ]
    ]
  }
}
EOT

## Install kube-router for CNI.
## ref: https://github.com/cloudnativelabs/kube-router/blob/master/docs/kubeadm.md
#kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter-all-features.yaml



## Report that it kind of worked.
echo OK
