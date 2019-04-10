# k6
IPv6-only Kubernetes -> DNS64 -> NAT64 -> Ubuntu 18.04 LXD Containers -> LXD -> Ubuntu 18.04 Bento Box -> Vagrant

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

**NOTE:** WIFI probably won't work here nor will VPN.

Let the provisioning script run to completion before continuing. You should see "OK".

```bash
vagrant up
```

SSH into the vagrant host.

```bash
vagrant ssh
```

Enter the master1 LXD container.

```bash
lxc exec master1 bash
```

Provision the LXD container.

```bash
cd /vagrant/master1

./provision.sh
```

Docker should now be installed and everything should be ready for you to initialize kubeadm.

```bash
./kubeadm-init.sh
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

### Expected Outcome

```bash
kubectl get pod --all-namespaces -o wide
#NAMESPACE     NAME                                      READY   STATUS    RESTARTS   AGE   IP                                       NODE      NOMINATED NODE   READINESS GATES
#kube-system   calico-kube-controllers-6cb7966b7-vdnn8   1/1     Running   0          22m   fd2e:236d:b96f:b9d1::1:2840              master1   <none>           <none>
#kube-system   calico-node-kqc6w                         0/1     Running   0          22m   fd42:467b:ca7b:a12b:216:3eff:feb0:12af   master1   <none>           <none>
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
