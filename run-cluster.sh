#!/bin/bash
set -e 

KIND_VERSION="0.8.1"
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
      echo "  single                  run a single node cluster"
      echo "  multi                   run a multi-node cluster with one control plan node and three worker nodes"
      echo 
      echo "flags:"
      echo "  -h --help               show help"
      echo "  -d --dashboard          include a dashboard in the cluster"
      echo "  -k --kind-version       use a specific version of kind"
      echo "  -m --metrics-server     include a metrics server in the cluster"
      echo "  -p --port <port>        include an nginx ingress for the specified port (can be used multiple times)"
      echo "  -v --version <version>  use a specific version of Kubernetes"
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
    -d|--dashboard)
      shift
      DASHBOARD=true
      ;;
    -k|--kind-version)
      shift
      KIND_VERSION=$1
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
    -v|--version)
      shift
      VERSION=$1
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
KIND="/tmp/kind-$KIND_VERSION"
if test ! -f $KIND; then
  echo "Downloading kind ($KIND_VERSION)"
  wget -q -O $KIND https://github.com/kubernetes-sigs/kind/releases/download/v$KIND_VERSION/kind-$(uname)-amd64
  chmod +x $KIND
fi

if [ -n "$VERSION" ]; then
  IMAGE_YAML_FRAGMENT="image: kindest/node:v${VERSION}"
fi

# Start building cluster config file
cat > /tmp/cluster.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  ${IMAGE_YAML_FRAGMENT}
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
  ${IMAGE_YAML_FRAGMENT}
- role: IMAGE_YAML_FRAGMENT
  ${IMAGE_YAML}
- role: worker
  ${IMAGE_YAML}
EOF
fi

# Trap SIGINT and SIGTERM so that the cluster can be shut down when Ctrl+C is pressed
cleanup() {
  echo
  if [ -n "$PROXYPID" ]; then
    echo "Stopping kubectl proxy ..."
    kill $PROXYPID
  fi
  $KIND delete cluster || exit $?
  exit 0
}
trap "cleanup" INT TERM

# Create the cluster
echo "Creating a $TYPE node cluster"
$KIND create cluster --config /tmp/cluster.yaml || exit $?

# Deploy nginx components if ports are specified
if [ ${#PORTS[@]} -gt 0 ]; then
  echo
  echo "Deploying nginx components for ingress ..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.27.0/deploy/static/mandatory.yaml
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.27.0/deploy/static/provider/baremetal/service-nodeport.yaml
  CONFIG='{"spec":{"template":{"spec":{"containers":[{"name":"nginx-ingress-controller","ports":['
  for PORT in "${PORTS[@]}"; do 
    CONFIG="$CONFIG{\"containerPort\":$PORT,\"hostPort\":$PORT},"
  done
  CONFIG=${CONFIG%?}']}],"nodeSelector":{"ingress-ready":"true"},"tolerations":[{"key":"node-role.kubernetes.io/master","operator":"Equal","effect":"NoSchedule"}]}}}}' 
  kubectl patch deployments -n ingress-nginx nginx-ingress-controller -p $CONFIG
  echo "Nginx components for ingress deployed"
fi

# Deploy metrics server if metrics flag is specified
if [ "$METRICS" = true ]; then
  echo 
  echo "Deploying metrics server ..."
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml
  kubectl patch deploy metrics-server -n kube-system --type json --patch '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"},{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname"}]'
  echo "Metrics server deployed"
fi

# Deploy dashboard if dashboard flag is specified
if [ "$DASHBOARD" = true ]; then
  echo
  echo "Deploying dashboard ..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-rc7/aio/deploy/recommended.yaml
  kubectl create clusterrolebinding default-admin --clusterrole cluster-admin --serviceaccount=default:default
  echo "Waiting for dashboard to become available..."
  kubectl wait --for=condition=Available deploy/kubernetes-dashboard -n kubernetes-dashboard --timeout 5m
  TOKEN=$(kubectl get secrets -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='default')].data.token}"|base64 -d)
  kubectl proxy > /dev/null &
  PROXYPID=$!
  echo "Dashboard deployed"
  echo
  echo "Dashboard URL:" 
  echo "http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
  echo
  echo "Dashboard Authentication Token:"
  echo $TOKEN
fi

# Display success message and wait for Ctrl+C to be pressed
echo 
echo "Your cluster is running"
echo "Press Ctrl+C to stop and delete the cluster"
echo
while [ 1 ]; do read _; done

