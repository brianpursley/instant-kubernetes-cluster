#!/bin/bash
set -e 

TYPE=single
PORTS=()
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
      echo "  -p --port <port>      includes an nginx ingress for the specified port (can be used multiple times)"
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
    -p|--port)
      shift
      PORTS+=($1)
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
  if ! command -v $1 > /dev/null; then
    >&2 echo "Error: $1 is not installed"
    exit 1
  fi
}
checkDependency docker
checkDependency wget
checkDependency unzip
checkDependency kubectl

# Download kind
if test ! -f /tmp/kind; then
  echo "Downloading kind"
  wget -q -O /tmp/kind https://github.com/kubernetes-sigs/kind/releases/download/v0.7.0/kind-$(uname)-amd64
  chmod +x /tmp/kind
fi

# Start building cluster config file
cat > /tmp/cluster.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
EOF

# Add extraPortMappings for ingress if ports are specified
if [ ${#PORTS[@]} -gt 0 ]; then
  cat >> /tmp/cluster.yaml << EOF
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
        authorization-mode: "AlwaysAllow"
  extraPortMappings:
EOF
  for PORT in "${PORTS[@]}"; do 
    cat >> /tmp/cluster.yaml << EOF
  - containerPort: $PORT
    hostPort: $PORT
    protocol: TCP
EOF
  done
fi

# Add additional worker nodes if a multi-node cluster
if [ "$TYPE" = "multi" ]; then
  cat >> /tmp/cluster.yaml << EOF
- role: worker
- role: worker
- role: worker
EOF
fi

# Trap SIGINT and SIGTERM so that the cluster can be shut down when Ctrl+C is pressed
cleanup() {
  echo
  /tmp/kind delete cluster || exit $?
  exit 0
}
trap "cleanup" INT TERM

# Create the cluster
echo "Creating a $TYPE node cluster"
/tmp/kind create cluster --config /tmp/cluster.yaml || exit $?

# Deploy nginx components if ports are specified
if [ ${#PORTS[@]} -gt 0 ]; then
  echo
  echo "Deploying nginx components for ingress"
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.27.0/deploy/static/mandatory.yaml
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.27.0/deploy/static/provider/baremetal/service-nodeport.yaml
  CONFIG='{"spec":{"template":{"spec":{"containers":[{"name":"nginx-ingress-controller","ports":['
  for PORT in "${PORTS[@]}"; do 
    CONFIG="$CONFIG{\"containerPort\":$PORT,\"hostPort\":$PORT},"
  done
  CONFIG=${CONFIG%?}']}],"nodeSelector":{"ingress-ready":"true"},"tolerations":[{"key":"node-role.kubernetes.io/master","operator":"Equal","effect":"NoSchedule"}]}}}}' 
  kubectl patch deployments -n ingress-nginx nginx-ingress-controller -p $CONFIG  
fi

# Deploy metrics server if metrics flag is specified
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
