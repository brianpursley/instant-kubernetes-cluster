#!/bin/sh

TYPE=single
while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo 
      echo "$0 - Run a temporary Kubernetes cluster"
      echo
      echo "Usage: $0 [type] [flags]"
      echo
      echo "type:"
      echo "  single                run a single node cluster"
      echo "  multi                 run a multi-node cluster with one control plan node and three worker nodes"
      echo 
      echo "flags:"
      echo "  -h --help             show help"
      echo "  -m --metrics-server   include a metrics server in the cluster"
      echo
      exit 0
      ;;
    single)
      TYPE=single
      shift
      ;;
    multi)
      TYPE=multi
      shift
      ;;
    -m|--metrics-server)
      METRICS=true
      shift
      ;;
    *)
      echo "unknown argument: $1"
      exit 1
      ;;
  esac
done

# Check to make sure everything that will be needed is installed
checkDependency() {
  if ! command -v docker > /dev/null; then
    >&2 echo "Error: docker is not installed"
    exit 1
  fi
}
checkDependency docker
if [ "$METRICS" = true ]; then
  checkDependency wget
  checkDependency unzip
  checkDependency kubectl
fi

# Download kind
if test ! -f /tmp/kind; then
  echo "Downloading kind"
  wget -q -O /tmp/kind https://github.com/kubernetes-sigs/kind/releases/download/v0.7.0/kind-$(uname)-amd64
  chmod +x /tmp/kind
fi

# Trap SIGINT and SIGTERM so that the cluster can be shut down when Ctrl+C is pressed
cleanup() {
  echo
  /tmp/kind delete cluster || exit $?
  exit 0
}
trap "cleanup" INT TERM

# Create a single node cluster
if [ "$TYPE" = "single" ]; then
  /tmp/kind create cluster || exit $?
fi

# Create a multi-node cluster
if [ "$TYPE" = "multi" ]; then
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
fi

# Optionally deploy metrics
if [ "$METRICS" = true ]; then
  echo 
  echo "Deploying metrics server"
  wget -q -O /tmp/metrics-server-master.zip https://github.com/kubernetes-sigs/metrics-server/archive/master.zip
  unzip -qq -u /tmp/metrics-server-master.zip -d /tmp
  rm /tmp/metrics-server-master.zip
  kubectl apply -f /tmp/metrics-server-master/deploy/1.8+/
  rm -rf /tmp/metrics-server-master
  kubectl patch deploy metrics-server -n kube-system --type json --patch '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"},{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname"}]'
fi

# Display success message and wait for Ctrl+C to be pressed
echo 
echo "Your cluster is running"
echo "Press Ctrl+C to stop and delete the cluster"
echo
while [ 1 ]; do read _; done
