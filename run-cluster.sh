#!/bin/sh

type=$1

if test ! -f /tmp/kind; then
  echo "Downloading kind"
  curl -Lo /tmp/kind https://github.com/kubernetes-sigs/kind/releases/download/v0.7.0/kind-$(uname)-amd64
  chmod +x /tmp/kind
fi

cleanup() {
  echo
  /tmp/kind delete cluster || exit $?
  exit 0
}
trap "cleanup" INT TERM

case "$type" in 
  "--single-node")
    /tmp/kind create cluster || exit $?
    ;;
  "--multi-node")
    cat >/tmp/multi-node.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
EOF
    /tmp/kind create cluster --config /tmp/multi-node.yaml || exit $?
    ;;
  *)
    echo
    echo "Usage: $0 [--single-node|--multi-node]"
    echo
    exit 0
    ;;
esac

echo 
echo "Your cluster is running"
echo "Press Ctrl+C to stop and delete the cluster"
echo

while [ 1 ]; do read _; done
