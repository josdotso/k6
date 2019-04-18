#!/usr/bin/env bash

set -euo pipefail

## Load settings.
source /vagrant/envrc

## If NOT first boot...
if [ -e /var/lib/provisioned ]; then
  export KUBECONFIG=/home/vagrant/.kube/config

  echo "==> Retry "kubectl get pods" until Kubernetes API comes online."
  while ! kubectl get pods --all-namespaces; do
    sleep 10
  done

  echo "==> Clean up calico-node pods from previous boot."
  kubectl -n kube-system delete pod -l k8s-app=calico-node

  echo "==> Get current pod status."
  kubectl get pods --all-namespaces

  echo "==> TIP: It takes about two minutes for all base pods to be Running."
  uptime

fi 

## Report general success.
echo OK
