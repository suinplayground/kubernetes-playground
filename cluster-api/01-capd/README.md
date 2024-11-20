# Setting up a Local Experimental Environment with CAPD (Cluster API Provider Docker)

## Prerequisites

- Docker
- kubectl
- kind
- clusterctl

## Create a management cluster using kind

CAPD uses a Kind cluster as the management cluster. Create a Kind configuration file to allow CAPD to access Docker on the host:

```yaml
# kind-cluster-with-extramounts.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  ipFamily: dual
nodes:
- role: control-plane
  extraMounts:
    - hostPath: /var/run/docker.sock
      containerPath: /var/run/docker.sock
```

Then, create the Kind cluster using this configuration:

```zsh
kind create cluster --config kind-cluster-with-extramounts.yaml
```

The output should look like this:

```zsh
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.31.0) 🖼
 ✓ Preparing nodes 📦  
 ✓ Writing configuration 📜 
 ✓ Starting control-plane 🕹️ 
 ✓ Installing CNI 🔌 
 ✓ Installing StorageClass 💾 
Set kubectl context to "kind-kind"
You can now use your cluster with:

kubectl cluster-info --context kind-kind

Thanks for using kind! 😊
```

## Initialize Cluster API with CAPD provider

Transform the Kind cluster into a management cluster by initializing it with clusterctl:

```zsh
export CLUSTER_TOPOLOGY=true && clusterctl init --infrastructure docker
```

This command installs the necessary Cluster API components, including the Docker infrastructure provider. The output should look like this:

```zsh
Fetching providers
Installing cert-manager version="v1.16.0"
Waiting for cert-manager to be available...
Installing provider="cluster-api" version="v1.8.5" targetNamespace="capi-system"
Installing provider="bootstrap-kubeadm" version="v1.8.5" targetNamespace="capi-kubeadm-bootstrap-system"
Installing provider="control-plane-kubeadm" version="v1.8.5" targetNamespace="capi-kubeadm-control-plane-system"
Installing provider="infrastructure-docker" version="v1.8.5" targetNamespace="capd-system"

Your management cluster has been initialized successfully!

You can now create your first workload cluster by running the following:

  clusterctl generate cluster [name] --kubernetes-version [version] | kubectl apply -f -
```

## Create a workload cluster

With the management cluster ready, you can create a workload cluster (a Kubernetes cluster managed by the management cluster):

```zsh
clusterctl generate cluster muscat \
  --flavor development \
  --kubernetes-version v1.31.0 \
  --control-plane-machine-count=3 \
  --worker-machine-count=3 \
  > muscat.yaml
```

Apply the configuration to create the cluster:

```zsh
kubectl apply -f muscat.yaml
```

The output should look like this:

```zsh
clusterclass.cluster.x-k8s.io/quick-start created
dockerclustertemplate.infrastructure.cluster.x-k8s.io/quick-start-cluster created
kubeadmcontrolplanetemplate.controlplane.cluster.x-k8s.io/quick-start-control-plane created
dockermachinetemplate.infrastructure.cluster.x-k8s.io/quick-start-control-plane created
dockermachinetemplate.infrastructure.cluster.x-k8s.io/quick-start-default-worker-machinetemplate created
dockermachinepooltemplate.infrastructure.cluster.x-k8s.io/quick-start-default-worker-machinepooltemplate created
kubeadmconfigtemplate.bootstrap.cluster.x-k8s.io/quick-start-default-worker-bootstraptemplate created
cluster.cluster.x-k8s.io/muscat created
```

## Access the workload cluster

Let's check the status of the workload cluster:

```zsh
kubectl get cluster
```

and see an output like this:

```zsh
NAME     CLUSTERCLASS   PHASE         AGE     VERSION
muscat   quick-start    Provisioned   5m47s   v1.31.0
```

Let's check the status of the machines:

```zsh
kubectl get machines
```

and see an output like this:

```zsh
NAME                            CLUSTER   NODENAME                        PROVIDERID                                 PHASE          AGE   VERSION
muscat-md-0-9mhvz-4xxcd-42nh8   muscat    muscat-md-0-9mhvz-4xxcd-42nh8   docker:////muscat-md-0-9mhvz-4xxcd-42nh8   Running        74s   v1.31.0
muscat-md-0-9mhvz-4xxcd-8hghp   muscat    muscat-md-0-9mhvz-4xxcd-8hghp   docker:////muscat-md-0-9mhvz-4xxcd-8hghp   Running        74s   v1.31.0
muscat-md-0-9mhvz-4xxcd-mxg7k   muscat    muscat-md-0-9mhvz-4xxcd-mxg7k   docker:////muscat-md-0-9mhvz-4xxcd-mxg7k   Running        74s   v1.31.0
muscat-r65sn-592c8              muscat                                                                               Provisioning   32s   v1.31.0
muscat-r65sn-xrzfl              muscat    muscat-r65sn-xrzfl              docker:////muscat-r65sn-xrzfl              Running        73s   v1.31.0
worker-08sx08                   muscat    muscat-worker-08sx08            docker:////muscat-worker-08sx08            Running        37s
worker-u6l39f                   muscat    muscat-worker-u6l39f            docker:////muscat-worker-u6l39f            Running        37s
worker-ydhg40                   muscat    muscat-worker-ydhg40            docker:////muscat-worker-ydhg40            Running        37s
```

To access the workload cluster, get the kubeconfig file:

```zsh
clusterctl get kubeconfig muscat > kubeconfig.muscat.yaml
```

Now let's verify we can connect to our new cluster and check its nodes using the new kubeconfig:

```zsh
kubectl --kubeconfig=./kubeconfig.muscat.yaml get nodes
```

Initially, the nodes will be in NotReady state as the CNI is not yet configured:

```zsh
NAME                            STATUS     ROLES           AGE   VERSION
muscat-md-0-9mhvz-4xxcd-42nh8   NotReady   <none>          63s   v1.31.0
muscat-md-0-9mhvz-4xxcd-8hghp   NotReady   <none>          68s   v1.31.0
muscat-md-0-9mhvz-4xxcd-mxg7k   NotReady   <none>          63s   v1.31.0
muscat-r65sn-592c8              NotReady   control-plane   18s   v1.31.0
muscat-r65sn-xrzfl              NotReady   control-plane   84s   v1.31.0
muscat-worker-08sx08            NotReady   <none>          60s   v1.31.0
muscat-worker-u6l39f            NotReady   <none>          60s   v1.31.0
muscat-worker-ydhg40            NotReady   <none>          60s   v1.31.0
```

## Setting up the CNI

For CAPD clusters, we need to install Calico as the CNI:

```zsh
kubectl --kubeconfig=./kubeconfig.muscat.yaml apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
```

The output should look like this:

```zsh
poddisruptionbudget.policy/calico-kube-controllers created
serviceaccount/calico-kube-controllers created
serviceaccount/calico-node created
serviceaccount/calico-cni-plugin created
configmap/calico-config created
customresourcedefinition.apiextensions.k8s.io/bgpconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/bgpfilters.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/bgppeers.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/blockaffinities.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/caliconodestatuses.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/clusterinformations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/felixconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/globalnetworkpolicies.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/globalnetworksets.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/hostendpoints.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamblocks.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamconfigs.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamhandles.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ippools.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipreservations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/kubecontrollersconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/networkpolicies.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/networksets.crd.projectcalico.org created
clusterrole.rbac.authorization.k8s.io/calico-kube-controllers created
clusterrole.rbac.authorization.k8s.io/calico-node created
clusterrole.rbac.authorization.k8s.io/calico-cni-plugin created
clusterrolebinding.rbac.authorization.k8s.io/calico-kube-controllers created
clusterrolebinding.rbac.authorization.k8s.io/calico-node created
clusterrolebinding.rbac.authorization.k8s.io/calico-cni-plugin created
daemonset.apps/calico-node created
deployment.apps/calico-kube-controllers created
```

Let's check the status of the pods in the kube-system namespace:

```zsh
kubectl --kubeconfig=./kubeconfig.muscat.yaml get pods -n kube-system
```

Initially, the Calico pods will be initializing:

```zsh
NAME                                         READY   STATUS              RESTARTS   AGE
calico-kube-controllers-868cbf9cc-tvjc5      0/1     ContainerCreating   0          20s
calico-node-4chq2                            0/1     Init:2/3            0          20s
calico-node-57mwq                            0/1     Init:2/3            0          20s
calico-node-6sj5j                            0/1     Init:2/3            0          20s
calico-node-8bnvh                            0/1     Init:2/3            0          20s
calico-node-jt9zx                            0/1     Init:2/3            0          20s
calico-node-l94s7                            0/1     Init:1/3            0          20s
calico-node-nnbxr                            0/1     Init:1/3            0          20s
calico-node-slbb8                            0/1     Init:2/3            0          20s
coredns-6f6b679f8f-666qp                     0/1     ContainerCreating   0          109s
coredns-6f6b679f8f-7844x                     0/1     ContainerCreating   0          109s
etcd-muscat-r65sn-xrzfl                      1/1     Running             0          114s
kube-apiserver-muscat-r65sn-xrzfl            1/1     Running             0          117s
kube-controller-manager-muscat-r65sn-xrzfl   1/1     Running             0          114s
kube-proxy-6gpq9                             1/1     Running             0          53s
kube-proxy-6qcj9                             1/1     Running             0          98s
kube-proxy-czxrx                             1/1     Running             0          95s
kube-proxy-dfv45                             1/1     Running             0          95s
kube-proxy-djrkk                             1/1     Running             0          98s
kube-proxy-h5jt6                             1/1     Running             0          110s
kube-proxy-j9xql                             1/1     Running             0          103s
kube-proxy-mt7xn                             1/1     Running             0          95s
kube-scheduler-muscat-r65sn-592c8            1/1     Running             0          51s
kube-scheduler-muscat-r65sn-xrzfl            1/1     Running             0          117s
```

After a few minutes, all nodes will become Ready:

```zsh
NAME                            STATUS   ROLES           AGE     VERSION
muscat-md-0-9mhvz-4xxcd-42nh8   Ready    <none>          4m20s   v1.31.0
muscat-md-0-9mhvz-4xxcd-8hghp   Ready    <none>          4m25s   v1.31.0
muscat-md-0-9mhvz-4xxcd-mxg7k   Ready    <none>          4m20s   v1.31.0
muscat-r65sn-592c8              Ready    control-plane   3m35s   v1.31.0
muscat-r65sn-xrzfl              Ready    control-plane   4m41s   v1.31.0
muscat-worker-08sx08            Ready    <none>          4m17s   v1.31.0
muscat-worker-u6l39f            Ready    <none>          4m17s   v1.31.0
muscat-worker-ydhg40            Ready    <none>          4m17s   v1.31.0
```

The setup of the local Kubernetes cluster using CAPD is now complete. This cluster is a fully functional Kubernetes cluster with three control plane nodes and three worker nodes.
