# instant-kubernetes-cluster

A bash script that automates the creation of a temporary Kubernetes single-node or multi-node cluster using [kind](https://kind.sigs.k8s.io/).

## Prerequisites

* [Docker](https://www.docker.com/)
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

## Usage

```
./run-cluster.sh - Run a temporary Kubernetes cluster

Usage: ./run-cluster.sh [type] [flags]

type:
  single                  run a single node cluster
  multi                   run a multi-node cluster with one control plan node and three worker nodes

flags:
  -h --help               show help
  -d --dashboard          include a dashboard in the cluster
  -k --kind-version       use a specific version of kind
  -m --metrics-server     include a metrics server in the cluster
  -p --port <port>        include an nginx ingress for the specified port (can be used multiple times)
  -v --version <version>  use a specific version of Kubernetes
```

## Examples

|Scenario|Example|
|--|--|
|Create a single-node cluster|`./run-cluster.sh`|
|Create a single-node cluster with a metrics server|`./run-cluster.sh -m`|
|Create a multi-node cluster:|`./run-cluster.sh multi`|
|Create a multi-node cluster with a metrics server|`./run-cluster.sh multi -m`|
|Create a multi-node cluster with nginx ingress for ports 8080 and 8081|`./run-cluster.sh multi -p 8080 -p 8081`|
|Create a single-node cluster using Kubernetes 1.18.0|`./run-cluster.sh -v 1.18.0`|

### Direct usage via curl
You can run the script directly via curl, like this:
```
sh <(curl -s https://raw.githubusercontent.com/brianpursley/instant-kubernetes-cluster/master/run-cluster.sh)
```

Or create an alias in your .bashrc, like this:
```
alias run-cluster="bash <(curl -s https://raw.githubusercontent.com/brianpursley/instant-kubernetes-cluster/master/run-cluster.sh)"
```
And then run it like this:
```
$ run-cluster <options>
```

## Example Output
```
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.17.0) 🖼
 ✓ Preparing nodes 📦  
 ✓ Writing configuration 📜 
 ✓ Starting control-plane 🕹️ 
 ✓ Installing CNI 🔌 
 ✓ Installing StorageClass 💾 
Set kubectl context to "kind-kind"
You can now use your cluster with:

kubectl cluster-info --context kind-kind

Have a question, bug, or feature request? Let us know! https://kind.sigs.k8s.io/#community 🙂

Cluster is running
Press Ctrl+C to shutdown the cluster

^C
Deleting cluster "kind" ...
```

## Troubleshooting

If you cancel `run-cluster.sh` while it is still creating the cluster, it may not be able to remove the cluster and you might get a message saying: 
```
ERROR: failed to delete cluster: failed to delete nodes: command "docker rm -f -v kind-control-plane" failed with error: exit status 1
```

Subsequently, if you try to run `run-cluster.sh` again without deleting the cluster, you will get an error like this:
```
ERROR: node(s) already exist for a cluster with the name "kind"
```

In both of these cases, you can manually delete the cluster by running:
```
/tmp/kind delete cluster
```
