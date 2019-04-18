# k6
IPv6-only Kubernetes -> kubeadm -> NAT64 -> Ubuntu 18.04 LXD Containers -> Ubuntu 18.04 -> Vagrant 

Also starring: [Google Public DNS64](https://developers.google.com/speed/public-dns/docs/dns64)

## Host Requirements

- IPv6 Global Unicast Address (GUA)
- IPv6 and IPv4 egress to Internet.
- Vagrant
- VirtualBox

## Getting Started

Clone this repo.

`cd` into your clone.

```bash
cd k6/
```

Spin up the Vagrant machine.

When prompted, select a public bridge with IPv6 enabled.

**NOTE:** WIFI will NOT work for k6. For a discussion of why a wired connection is required,
          see: https://discuss.linuxcontainers.org/t/another-networking-issue-or-how-to-connect-containers-to-more-than-one-network-using-a-bridge-or-macvlan/1396/4

Let the provisioning script run to completion before continuing. You should see "OK".

```bash
vagrant up
```

SSH into the vagrant host.

```bash
vagrant ssh
```

```
kubectl get pod --all-namespaces -o wide
## ^ Run this as many times as you need before continuing.
##   You can append "-w" to the end of the command above
##   to watch for changes. Press CTRL+c to cancel the watch.
```

At this point, IPv6-only Kubernetes should be running. You can now proceed to installing things like Ingress and configuring storage provisioners as needed.

**TIP:** It takes about 2 minutes for the cluster to return after `vagrant halt; vagrant up`.

#### Expected Outcome

```bash
kubectl get pod --all-namespaces -o wide

```

```bash
kubectl get node -o wide

```

## Using Kubernetes from outside the VM

**NOTE:** This is broken right now, due to: https://github.com/hashicorp/vagrant/issues/10782

Once you complete the Getting Started steps, you should be able to exit the Vagrant machine and run commands against the Kubernetes API from outsdie the VM.

Here is how to do that:

```bash
## Enter the k6 directory.
cd k6/

## Set the KUBECONFIG variable.
export KUBECONFIG=$(pwd)/admin.conf

## Run kubectl.
kubectl get pods --all-namespaces -o wide
```
