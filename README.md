# instant-kubernetes-cluster

Automates the creation of a temporary Kubernetes single-node or multi-node cluster using [kind](https://kind.sigs.k8s.io/), allowing you to spin up a cluster in one line, without having to install anything other than Docker.

## Prerequisites

[Docker](https://www.docker.com/)

## Usage

Create a single-node cluster:
```
sh <(curl -s https://raw.githubusercontent.com/brianpursley/instant-kubernetes-cluster/master/run-cluster.sh) --single-node
```

Create a multi-node cluster:
```
sh <(curl -s https://raw.githubusercontent.com/brianpursley/instant-kubernetes-cluster/master/run-cluster.sh) --multi-node
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
