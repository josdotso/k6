#!/usr/bin/env bash

set -euo pipefail

## Install calico for IPv6.
kubectl apply -f /vagrant/kubernetes/calico.yaml

## Report that it kind of worked.
echo OK
