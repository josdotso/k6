#!/usr/bin/env bash
set -ueo pipefail

function main() {
    echo "kubernetes bootstrap.sh called"

    configure_kube
    configure_helm
    #configure_metallb
    configure_ingress
    configure_rook
    exit 0
}

function configure_kube() {

    # Configure kubeconfig for remainder of script
    export KUBECONFIG=/etc/kubernetes/admin.conf

    ## Remove master taints
    kubectl taint nodes --all node-role.kubernetes.io/master- || true

    ## Deploy a pod network (calico for IPv6)
    # kubectl apply -f /vagrant/kubernetes/calico.yaml

}

function configure_helm() {

    # Install helm
    if ! command -v helm; then
        curl https://raw.githubusercontent.com/helm/helm/master/scripts/get | sudo bash
    fi

    # Install tiller for RBAC
    if ! kubectl get deployments -n kube-system | grep tiller; then
        kubectl --namespace kube-system create serviceaccount tiller
        kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
        helm init --service-account tiller --wait
        helm repo update
    fi
}

function configure_metallb() {

    return 0

    # Get the IP of the default route interface

    # Install MetalLB using Helm
    #   Send chart overrides through sdtdin
    #   NOTE: Non-floating IP is something like `192.168.1.7/32` in OpenStack.
    if ! helm ls | grep metallb; then
	EXTERNAL_IP=$(ip -6 route get 2001:4860:4860::6464 | grep -oP 'src \K\S+')
	helm delete --purge metallb || true
        helm install --name metallb stable/metallb -f - << EOF
prometheus:
  scrapeAnnotations: false
configInline:
  address-pools:
  - name: default
    protocol: layer2
    addresses:
    - fd42:25fa:cd98:32c3:ffff:ffff::/96
EOF
    fi
#   - $EXTERNAL_IP/128
#   - fd42:73fd:d832:c84f::198:0/110
#   - $EXTERNAL_IP/64
#   - fd42:73fd:d832:c84f::/64
}

function configure_ingress() {
    # Install Ingress
    if ! helm ls | grep nginx-ingress; then
	helm delete --purge nginx-ingress || true
        helm install --name nginx-ingress stable/nginx-ingress -f - << EOF
# Enabling this allows external-dns access to host names serviced by ingress, so that
# external-dns can set records in the DNS provider
controller:
  publishService:
    enabled: true
EOF
    fi
}

function configure_rook() {


    # https://github.com/rook/rook/blob/master/Documentation/helm-operator.md
    # https://github.com/rook/rook/tree/master/cluster/charts/rook-ceph
    # kubectl edit cephclusters.ceph.rook.io -n rook-ceph
    # kubectl edit daemonset -n rook-ceph rook-discover
    helm repo add rook-stable https://charts.rook.io/stable
    helm search rook
    helm install --name rook-ceph --namespace rook-ceph rook-stable/rook-ceph
    kubectl delete -f - << EOF
apiVersion: ceph.rook.io/v1
kind: CephCluster
metadata:
  name: rook-ceph
  namespace: rook-ceph
EOF

    kubectl create -f - << EOF
apiVersion: ceph.rook.io/v1
kind: CephCluster
metadata:
  name: rook-ceph
  namespace: rook-ceph
spec:
  cephVersion:
    # For the latest ceph images, see https://hub.docker.com/r/ceph/ceph/tags
    image: ceph/ceph:v13.2.5-20190319
  dataDirHostPath: /var/lib/rook
  mon:
    count: 1
    allowMultiplePerNode: false
  dashboard:
    enabled: true
  storage:
    useAllNodes: true
    useAllDevices: true
    deviceFilter: loop*
    directories:
    - path: "/rook/storage-dir"
    storeConfig:
      storeType: bluestore
      databaseSizeMB: 256
      journalSizeMB: 256
EOF

# 2019-04-20 07:03:35.799358 E | op-cluster: unknown ceph major version. failed to get version job log to detect version. failed to read from stream. pods "rook-ceph-detect-version-pr2cr" is forbidden: User "system:serviceaccount:rook-ceph:rook-ceph-system" cannot get resource "pods/log" in API group "" in the namespace "rook-ceph"
# add kubectl edit role rook-ceph-system -n rook-ceph   # pods/log
}

function configure_loopback_block_devices() {
    # https://git.osso.nl/kubernetes/rook-ceph/tree/41e5d1ff49108b09f0fc0db9c1ba6cb861af12dd


    for i in {0..1}; do
	if [ ! -e /dev/loop$i ]; then
	    mknod /dev/loop$i b 7 $i
	    #chown --reference=/dev/loop0 /dev/loop$i
	    #chmod --reference=/dev/loop0 /dev/loop$i
	    chown root:disk /dev/loop$i
	    chmod u+rw /dev/loop$i
	    chmod g+rw /dev/loop$i
	fi
	if [ ! -e /root/diskimage$i ]; then
	    dd if=/dev/zero of=/root/diskimage$i bs=1M count=2048
	    losetup -fP /root/diskimage$i
	fi
    done
}


function configure_kubeconfig() {
    remote_access_uri=${1:-}
    remote_access_domain=$(echo "$remote_access_uri"| cut -f2- -d.)

    # Setup user's kubeconfig
    mkdir -p $HOME/.kube
    cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
    echo "Local KUBECONFIG created at $HOME/.kube/config"

    # Setup the remote kubeconfig
    if [[ ! -z "$remote_access_uri" ]]; then
        cp -f /etc/kubernetes/admin.conf $HOME/.kube/config.remote
        sed -i 's/kubernetes-//g' $HOME/.kube/config.remote
        sed -i "s/admin@kubernetes/$remote_access_domain/g" $HOME/.kube/config.remote
        sed -i "s/kubernetes/$remote_access_domain/g" $HOME/.kube/config.remote

        KUBECONFIG=/etc/kubernetes/admin.conf
        ingress_external_lb_ip=$(kubectl get svc| grep nginx-ingress-controller | awk '{print $4}')
        sed -i "s/$ingress_external_lb_ip/$remote_access_uri/g" $HOME/.kube/config.remote

        echo "Remote KUBECONFIG created at $HOME/.kube/config.remote"
    fi

    # Ensure ownership
    chown -R $SUDO_UID:$SUDO_GID $HOME/.kube
}

function wait_check() {
    noun=$1
    adjective=$2
    binary_test=$3
    
    echo "CHECK: Waiting for $noun to become $adjective"
    error=true
    num_cycles=180
    for i in `seq 1 $num_cycles`; do
        if eval $binary_test &>/dev/null; then
            echo "  SUCCESS: $noun have become $adjective"
            error=false
            break
        else
            echo "  WAITING: $noun have not yet become $adjective.  Trying again after 2 seconds ($i/$num_cycles)"
            error=true
            sleep 2
        fi
    done
    if $error; then
        echo "  FAIL: $noun did not become $adjective"
        exit 1
    fi
}


function verify_setup() {

    wait_check "Cluster" "Responsive" "kubectl cluster-info"
    
    echo "Create a test-pod writing to a test-pvc"
    kubectl apply -f https://raw.githubusercontent.com/MaZderMind/hostpath-provisioner/master/manifests/test-claim.yaml
    kubectl apply -f https://raw.githubusercontent.com/MaZderMind/hostpath-provisioner/master/manifests/test-pod.yaml

    wait_check "All PODs" "Running" "[[ \$(kubectl get po --all-namespaces | grep -v -E '(STATUS|Running)' | wc -l) == 0 ]]"
    wait_check "All PVCs" "Bound"   "[[ \$(kubectl get pvc --all-namespaces | grep -v -E '(STATUS|Bound)' | wc -l) == 0 ]]"
    wait_check "All SVCs" "Up"      "[[ \$(kubectl get svc --all-namespaces | grep -i pending | wc -l) == 0 ]]"

    ingress_external_lb_ip=$(kubectl get svc| grep nginx-ingress-controller | awk '{print $4}')
    wait_check "Ingress Controller LoadBalancer Service" "Up" "curl $ingress_external_lb_ip &>/dev/null"

    wait_check "Test-pvc disk resources" "Written" "ls -f /var/kubernetes/default-hostpath-test-claim-pvc-*/dates"
    
    echo "Removing test-pod and test-pvc resources"
    kubectl delete pod hostpath-test-pod
    kubectl delete pvc hostpath-test-claim

    wait_check "Test-pvc disk resources" "Deleted" "! ls /var/kubernetes/default-hostpath-test-claim-pvc-*"
}

#####################################################################
# Run the main program
main "$@"
