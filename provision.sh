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
  kernel-headers-$(uname -r) \
  kernel-modules-$(uname -r) \
  lxd \
  lxd-client \
  nmap \
  software-properties-common \
  vim

## Initialize LXD with Preseed YAML heredoc.
cat /vagrant/lxd.yaml | sudo lxd init --preseed

## Launch LXD container for DNS64, NAT64: "n64"
lxc launch --profile n64 ubuntu:18.04 n64

## Launch LXD container for Kubernetes Master #1: master1
lxc launch --profile master1 ubuntu:18.04 master1

## Report that it kind of worked.
echo OK
