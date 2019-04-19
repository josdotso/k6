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
# NAMESPACE     NAME                                      READY   STATUS    RESTARTS   AGE     IP                                       NODE      NOMINATED NODE   READINESS GATES
# kube-system   calico-kube-controllers-6cb7966b7-qjm76   1/1     Running   0          6m35s   fd2e:236d:b96f:b9d1::1:2840              master1   <none>           <none>
# kube-system   calico-node-878mf                         1/1     Running   0          3m43s   fd42:8c05:3cde:3420:216:3eff:fe4e:5781   node1     <none>           <none>
# kube-system   calico-node-dhd49                         1/1     Running   0          43s     fd42:8c05:3cde:3420:216:3eff:fef4:bf4d   node2     <none>           <none>
# kube-system   calico-node-h884f                         1/1     Running   0          6m35s   fd42:8c05:3cde:3420:216:3eff:fe88:a1a0   master1   <none>           <none>
# kube-system   coredns-fb8b8dccf-lkgjx                   1/1     Running   1          6m35s   fd2e:236d:b96f:b9d1::1:2841              master1   <none>           <none>
# kube-system   coredns-fb8b8dccf-ll4mv                   1/1     Running   1          6m35s   fd2e:236d:b96f:b9d1::1:2842              master1   <none>           <none>
# kube-system   etcd-master1                              1/1     Running   0          5m48s   fd42:8c05:3cde:3420:216:3eff:fe88:a1a0   master1   <none>           <none>
# kube-system   kube-apiserver-master1                    1/1     Running   0          5m45s   fd42:8c05:3cde:3420:216:3eff:fe88:a1a0   master1   <none>           <none>
# kube-system   kube-controller-manager-master1           1/1     Running   0          5m50s   fd42:8c05:3cde:3420:216:3eff:fe88:a1a0   master1   <none>           <none>
# kube-system   kube-proxy-8fwbl                          1/1     Running   0          6m35s   fd42:8c05:3cde:3420:216:3eff:fe88:a1a0   master1   <none>           <none>
# kube-system   kube-proxy-pqwpk                          1/1     Running   0          43s     fd42:8c05:3cde:3420:216:3eff:fef4:bf4d   node2     <none>           <none>
# kube-system   kube-proxy-qb842                          1/1     Running   0          3m43s   fd42:8c05:3cde:3420:216:3eff:fe4e:5781   node1     <none>           <none>
# kube-system   kube-scheduler-master1                    1/1     Running   0          5m27s   fd42:8c05:3cde:3420:216:3eff:fe88:a1a0   master1   <none>           <none>
```

```bash
kubectl get node -o wide
# NAME      STATUS   ROLES    AGE     VERSION   INTERNAL-IP                              EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
# master1   Ready    master   7m23s   v1.14.1   fd42:8c05:3cde:3420:216:3eff:fe88:a1a0   <none>        Ubuntu 18.04.2 LTS   4.15.0-29-generic   docker://18.9.5
# node1     Ready    node     4m11s   v1.14.1   fd42:8c05:3cde:3420:216:3eff:fe4e:5781   <none>        Ubuntu 18.04.2 LTS   4.15.0-29-generic   docker://18.9.5
# node2     Ready    node     72s     v1.14.1   fd42:8c05:3cde:3420:216:3eff:fef4:bf4d   <none>        Ubuntu 18.04.2 LTS   4.15.0-29-generic   docker://18.9.5
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
