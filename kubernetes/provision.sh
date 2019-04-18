#!/usr/bin/env bash

set -euo pipefail
set -x

## Try to avoid slow boots in LXD due to networkd vs. IPv6
systemctl disable systemd-networkd-wait-online.service
systemctl mask systemd-networkd-wait-online.service
systemctl stop systemd-networkd-wait-online.service

## Retry curl until NAT64 comes up.
REQUISITE_HOSTS="dl.k8s.io packages.cloud.google.com download.docker.com security.ubuntu.com archive.ubuntu.com"
for h in ${REQUISITE_HOSTS}; do
  echo "Retrying until works: $ curl ${h}"
  while ! curl -6 -vsL --max-time 5 -o /dev/null http://${h}; do
    sleep 1
    echo "Trying again..."
  done
done

## Update apt cache.
sudo apt update

## Install tools.
sudo apt install -y \
  apt-transport-https \
  ca-certificates \
  dnsutils \
  nmap \
  software-properties-common \
  vim

## If first boot...
if [ ! -e /var/lib/provisioned ]; then

  ## Install Docker for IPv6.
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  sudo mkdir -p /etc/docker
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
  sudo mkdir -p /etc/systemd/system/docker.service.d
  cat <<EOF | sudo tee /etc/systemd/system/docker.service.d/override.conf
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H unix:// -D -H tcp://127.0.0.1:2375
EOF
  sudo apt update
  sudo apt install -y docker-ce
  sudo systemctl enable docker
  if getent passwd vagrant; then
    sudo usermod -aG docker vagrant
  fi
  if getent passwd ubuntu; then
    sudo usermod -aG docker ubuntu
  fi

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
  sudo systemctl enable kubelet

  ## Remove IPv4 address on docker0
  sudo ip addr del 172.17.0.1/16 dev docker0

  ## Configure preflight errors to ignore.
  ##
  ## ref: https://github.com/corneliusweig/kubernetes-lxd#installing-kubernetes-in-the-lxc-container
  IGNORED_PREFLIGHT_ERRORS=FileContent--proc-sys-net-bridge-bridge-nf-call-iptables,FileContent--proc-sys-net-bridge-bridge-nf-call-ip6tables

  ## Preheat Docker image cache.
  sudo kubeadm config images pull \
    --config=/vagrant/kubernetes/kubeadm.yaml

  ## Run appropriate second stage for this node.
  case $(hostname -s) in
    master1)
      ## master1 is special in that it initializes the
      ## kubeadm cluster. TODO: Make it possible to
      ## replace master1 without re-initializing.

      ## Run kubeadm.
      sudo kubeadm init \
        --config=/vagrant/kubernetes/kubeadm.yaml \
        --ignore-preflight-errors=${IGNORED_PREFLIGHT_ERRORS} \
        | tee kubeadm.log

      ## Extract kubeadm join command for nodes.
      cat <<EOF | sudo tee /vagrant/kubernetes/join-node.sh
#!/usr/bin/env bash
set -euo pipefail
$(grep 'kubeadm join\|discovery-token-ca-cert-hash' kubeadm.log) \
  --ignore-preflight-errors=${IGNORED_PREFLIGHT_ERRORS}
EOF
      chmod +x /vagrant/kubernetes/join-node.sh

      ## TODO: Extract kubeadm join command for masters.
      ## ref: https://kubernetes.io/docs/setup/independent/high-availability/

      ## Give the user a copy of root's kubeconfig.
      export ADMIN_KUBECONFIG=/etc/kubernetes/admin.conf
      export KUBECONFIG=~/.kube/config
      if [ ! -e ${KUBECONFIG} ]; then
        mkdir -p $(dirname ${KUBECONFIG})
        touch ${KUBECONFIG}
        chmod 0600 ${KUBECONFIG}
        sudo cat ${ADMIN_KUBECONFIG} > ${KUBECONFIG}
      fi

      ## Configure a host mount copy of KUBECONFIG
      ## for use inside the vagrant machine.
      sudo cat ${KUBECONFIG} > /vagrant/admin.conf
      chmod 0600 /vagrant/admin.conf

      ## Remove master taints.
      kubectl taint nodes --all node-role.kubernetes.io/master- || true

      ## Install calico for IPv6.
      kubectl apply -f /vagrant/kubernetes/calico.yaml

      ## Give it a moment.
      sleep 20

      ## Check on it.
      kubectl get node -o wide
      kubectl get pod --all-namespaces -o wide
    ;;
    master*)
      ## ref: https://kubernetes.io/docs/setup/independent/high-availability/
      echo "TODO: Support multiple masters."
      #sudo /vagrant/kubernetes/join-master.sh
    ;;
    node*)
      sudo /vagrant/kubernetes/join-node.sh
    ;;
  esac

fi

## Mark provisioned
touch /var/lib/provisioned

## Report general success.
echo OK
