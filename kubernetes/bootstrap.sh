#!/usr/bin/env bash
set -ueo pipefail

function main() {
    echo "kubernetes bootstrap.sh called"
    echo "exiting early"
    exit 0

    confgure_kube
    configure_helm
    configure_metallb
    configure_ingress
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
    EXTERNAL_IP=$(ip -6 route get 2001:4860:4860::6464 | grep -oP 'src \K\S+')
    # Install MetalLB using Helm
    #   Send chart overrides through sdtdin
    #   NOTE: Non-floating IP is something like `192.168.1.7/32` in OpenStack.
    if ! helm ls | grep metallb; then
	helm delete --purge metallb || true
        helm install --name metallb stable/metallb -f - << EOF
prometheus:
  scrapeAnnotations: false
configInline:
  address-pools:
  - name: default
    protocol: layer2
    addresses:
#   - $EXTERNAL_IP/128
#   - fd42:73fd:d832:c84f::198:0/110
#   - $EXTERNAL_IP/64
    - fd42:73fd:d832:c84f::/64
EOF
    fi
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
    # NONE OF THIS WORKS

    # Install Rook Ceph
    #   ref: https://github.com/rook/rook/blob/master/Documentation/ceph-quickstart.md
    #   ref: https://github.com/rook/rook.github.io/blob/master/docs/rook/v0.7/helm-operator.md
    kubectl apply -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/common.yaml
    kubectl apply -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/operator.yaml
    kubectl apply -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/cluster.yaml


    kubectl delete -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/common.yaml
    kubectl delete -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/operator.yaml
    kubectl delete -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/cluster.yaml

    helm repo add rook-master https://charts.rook.io/master
    helm search rook
    helm install --name rook rook-master/rook \
	 --namespace kube-system \
	 --version v0.7.0-10.g3bcee98 \
	 --set rbacEnable=false


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
  dataDirHostPath: /var/lib/rook3
  mon:
    count: 3
    allowMultiplePerNode: false
  dashboard:
    enabled: true
  storage:
    useAllNodes: true
    useAllDevices: false
    storeConfig:
      storeType: bluestore
      databaseSizeMB: 1024
      journalSizeMB: 1024
EOF
    # kubectl delete cephclusters.ceph.rook.io rook-ceph -n rook-ceph
    # helm delete --purge rook

}


function guide() {
    # CONFIGURE CEPH USING TUTORIAL, has an RBAC error haven't figured out yet
    # https://akomljen.com/rook-cloud-native-on-premises-persistent-storage-for-kubernetes-on-kubernetes/

    helm repo add rook-master https://charts.rook.io/master
    helm search rook
    helm install --name rook rook-master/rook \
	 --namespace kube-system \
	 --version v0.7.0-136.gd13bc83 \
	 --set rbacEnable=true
    kubectl create namespace rook

cat << EOF | kubectl create -n rook -f -
apiVersion: rook.io/v1alpha1
kind: Cluster
metadata:
  name: rook
spec:
  dataDirHostPath: /var/lib/rook
  storage:
    useAllNodes: true
    useAllDevices: false
    storeConfig:
      storeType: bluestore
      databaseSizeMB: 1024
      journalSizeMB: 1024
EOF

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
