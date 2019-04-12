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

### Initialize kubadm on master1

Enter the master1 LXD container.

```bash
lxc exec master1 bash
```

Provision it.

```bash
cd /vagrant/kubernetes

./provision.sh
```

Docker should now be installed and everything should be ready for you to initialize kubeadm.

```bash
./kubeadm-init.sh
```

**IMPORTANT:** Copy the full `kubeadm join` command displayed at the end of the command above. You'll need this to join subsequent nodes to the Kubernetes cluster.

A redacted example of what you should see and copy to a secure note for later:

```bash
# kubeadm join [fd42:dbd:c3ea:e9db:216:3eff:fef8:fce6]:6443 --token 66fz78.abcabcabcabcabca \
#   --discovery-token-ca-cert-hash sha256:9a9c75625662cb2bd1f4e41c582eb635653384b321ff06fc3c99bd8a41281f69
```

Deploy Calico and wait until all pods are Running, including CoreDNS. CoreDNS pods may need one or two restarts before everything stablizes. This is unfortunate but normal.

```bash
./calico-init.sh

kubectl get pod --all-namespaces -o wide
## ^ Run this as many times as you need before continuing.
##   You can append "-w" to the end of the command above
##   to watch for changes. Press CTRL+c to cancel the watch.
```

At this point, IPv6-only Kubernetes should be running. You can now proceed to installing things like Ingress and configuring storage provisioners as needed.

#### Expected Outcome

```bash
kubectl get pod --all-namespaces -o wide
#NAMESPACE     NAME                                      READY   STATUS    RESTARTS   AGE   IP                                       NODE      NOMINATED NODE   READINESS GATES
#kube-system   calico-kube-controllers-6cb7966b7-vdnn8   1/1     Running   0          22m   fd2e:236d:b96f:b9d1::1:2840              master1   <none>           <none>
#kube-system   calico-node-kqc6w                         1/1     Running   0          22m   fd42:467b:ca7b:a12b:216:3eff:feb0:12af   master1   <none>           <none>
#kube-system   coredns-fb8b8dccf-fjv7t                   1/1     Running   1          23m   fd2e:236d:b96f:b9d1::1:2842              master1   <none>           <none>
#kube-system   coredns-fb8b8dccf-v92xn                   1/1     Running   1          23m   fd2e:236d:b96f:b9d1::1:2841              master1   <none>           <none>
#kube-system   etcd-master1                              1/1     Running   0          23m   fd42:467b:ca7b:a12b:216:3eff:feb0:12af   master1   <none>           <none>
#kube-system   kube-apiserver-master1                    1/1     Running   0          22m   fd42:467b:ca7b:a12b:216:3eff:feb0:12af   master1   <none>           <none>
#kube-system   kube-controller-manager-master1           1/1     Running   0          22m   fd42:467b:ca7b:a12b:216:3eff:feb0:12af   master1   <none>           <none>
#kube-system   kube-proxy-lm6tk                          1/1     Running   0          23m   fd42:467b:ca7b:a12b:216:3eff:feb0:12af   master1   <none>           <none>
#kube-system   kube-scheduler-master1                    1/1     Running   0          23m   fd42:467b:ca7b:a12b:216:3eff:feb0:12af   master1   <none>           <none>
```

```bash
kubectl get node -o wide
#NAME      STATUS   ROLES    AGE   VERSION   INTERNAL-IP                              EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
#master1   Ready    master   24m   v1.14.1   fd42:467b:ca7b:a12b:216:3eff:feb0:12af   <none>        Ubuntu 18.04.2 LTS   4.15.0-29-generic   docker://18.9.4
```

### Join node1 to the cluster.

SSH into the vagrant host.

```bash
vagrant ssh
```

Enter the node1 LXD container.

```bash
lxc exec node1 bash
```

Provision it.

```bash
cd /vagrant/kubernetes

./provision.sh
```

Join this node to the Kubernetes cluster.

NOTE: You MUST add the pre-flight check ignore flags due to running Kubernetes in LXD.

```bash
## This is only an example.
## You must splice together the join command you copied earlier
## with the ignore-preflight-errors flag below.
##
# kubeadm join [fd42:dbd:c3ea:e9db:216:3eff:fef8:fce6]:6443 --token 66fz78.abcabcabcabcabca \
#   --discovery-token-ca-cert-hash sha256:9a9c75625662cb2bd1f4e41c582eb635653384b321ff06fc3c99bd8a41281f69 \
#   --ignore-preflight-errors=FileContent--proc-sys-net-bridge-bridge-nf-call-iptables,FileContent--proc-sys-net-bridge-bridge-nf-call-ip6tables
```

```bash
# Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

Check out the result over:

```bash
export KUBECONFIG=/etc/kubernetes/kubelet.conf

kubectl get nodes -o wide
# NAME      STATUS   ROLES    AGE   VERSION   INTERNAL-IP                             EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
# master1   Ready    master   89m   v1.14.1   fd42:dbd:c3ea:e9db:216:3eff:fef8:fce6   <none>        Ubuntu 18.04.2 LTS   4.15.0-29-generic   docker://18.9.5
# node1     Ready    <none>   69m   v1.14.1   fd42:dbd:c3ea:e9db:216:3eff:fea8:9b2a   <none>        Ubuntu 18.04.2 LTS   4.15.0-29-generic   docker://18.9.5

kubectl get pod --all-namespaces -o wide
# NAMESPACE     NAME                                      READY   STATUS    RESTARTS   AGE   IP                                      NODE      NOMINATED NODE   READINESS GATES
# kube-system   calico-kube-controllers-6cb7966b7-zpkdd   1/1     Running   0          87m   fd2e:236d:b96f:b9d1::1:2841             master1   <none>           <none>
# kube-system   calico-node-58spd                         1/1     Running   0          21m   fd42:dbd:c3ea:e9db:216:3eff:fea8:9b2a   node1     <none>           <none>
# kube-system   calico-node-fgpth                         1/1     Running   0          21m   fd42:dbd:c3ea:e9db:216:3eff:fef8:fce6   master1   <none>           <none>
# kube-system   coredns-fb8b8dccf-7jzgg                   1/1     Running   1          88m   fd2e:236d:b96f:b9d1::1:2840             master1   <none>           <none>
# kube-system   coredns-fb8b8dccf-hf8g4                   1/1     Running   1          88m   fd2e:236d:b96f:b9d1::1:2842             master1   <none>           <none>
# kube-system   etcd-master1                              1/1     Running   0          87m   fd42:dbd:c3ea:e9db:216:3eff:fef8:fce6   master1   <none>           <none>
# kube-system   kube-apiserver-master1                    1/1     Running   0          87m   fd42:dbd:c3ea:e9db:216:3eff:fef8:fce6   master1   <none>           <none>
# kube-system   kube-controller-manager-master1           1/1     Running   0          87m   fd42:dbd:c3ea:e9db:216:3eff:fef8:fce6   master1   <none>           <none>
# kube-system   kube-proxy-pgskt                          1/1     Running   0          68m   fd42:dbd:c3ea:e9db:216:3eff:fea8:9b2a   node1     <none>           <none>
# kube-system   kube-proxy-x6lss                          1/1     Running   0          88m   fd42:dbd:c3ea:e9db:216:3eff:fef8:fce6   master1   <none>           <none>
# kube-system   kube-scheduler-master1                    1/1     Running   0          87m   fd42:dbd:c3ea:e9db:216:3eff:fef8:fce6   master1   <none>           <none>
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
