# Testing Helm Chart Distribution with Cluster API

## Goals

- Deploy the same Helm chart to all clusters at once
- Deploy Helm chart to specific clusters (selected by labels)
- Deploy Helm chart from a private registry

## Prerequisites

- Docker
  - Memory: 16GB or more recommended
- kubectl
- kind
- clusterctl

## Setup

### 1. Create a management cluster using kind

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

Create the Kind cluster using this configuration:

```bash
kind create cluster --config kind-cluster-with-extramounts.yaml
```

### 2. Initialize Cluster API with CAPD provider

Transform the Kind cluster into a management cluster by initializing it with clusterctl:

```bash
export CLUSTER_TOPOLOGY=true
clusterctl init --infrastructure docker --addon helm
```

This command installs:
- Docker infrastructure provider (CAPD)
- Helm addon provider (for deploying Helm charts to workload clusters)

Wait for all CAPI components to be ready:

```bash
kubectl wait --for=condition=Available --timeout=300s -n capi-system deployments --all && \
kubectl wait --for=condition=Available --timeout=300s -n capi-kubeadm-bootstrap-system deployments --all && \
kubectl wait --for=condition=Available --timeout=300s -n capi-kubeadm-control-plane-system deployments --all && \
kubectl wait --for=condition=Available --timeout=300s -n capd-system deployments --all && \
kubectl wait --for=condition=Available --timeout=300s -n caaph-system deployments --all
```

### 3. Create workload clusters

Generate cluster manifests for "muscat" and "delaware":

```bash
# Create muscat cluster manifest
clusterctl generate cluster muscat \
  --flavor development \
  --kubernetes-version v1.28.0 \
  --control-plane-machine-count=3 \
  --worker-machine-count=3 \
  > muscat.yaml

# Create delaware cluster manifest
clusterctl generate cluster delaware \
  --flavor development \
  --kubernetes-version v1.28.0 \
  --control-plane-machine-count=3 \
  --worker-machine-count=3 \
  > delaware.yaml
```

Create both clusters:

```bash
kubectl apply -f muscat.yaml
kubectl apply -f delaware.yaml
```

Get kubeconfig files:

```bash
# Get kubeconfig for muscat
clusterctl get kubeconfig muscat > muscat-kubeconfig.yaml

# Get kubeconfig for delaware
clusterctl get kubeconfig delaware > delaware-kubeconfig.yaml
```

### 4. Set up CNI (Calico)

Install Calico on both clusters:

```bash
# Install Calico on muscat
kubectl --kubeconfig=muscat-kubeconfig.yaml apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# Install Calico on delaware
kubectl --kubeconfig=delaware-kubeconfig.yaml apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml
```

Wait for nodes to be ready:

```bash
# Wait for muscat nodes
kubectl --kubeconfig=muscat-kubeconfig.yaml wait --for=condition=Ready nodes --all --timeout=300s

# Wait for delaware nodes
kubectl --kubeconfig=delaware-kubeconfig.yaml wait --for=condition=Ready nodes --all --timeout=300s
```

## Deploy Helm Charts

### Deploy to All Clusters

Create a HelmChartProxy resource to deploy nginx to all clusters:

```yaml
# helm-chart-proxy-nginx.yaml
apiVersion: addons.cluster.x-k8s.io/v1alpha1
kind: HelmChartProxy
metadata:
  name: nginx
spec:
  clusterSelector: {} # Empty selector means "select all clusters"
  repoURL: oci://registry-1.docker.io/bitnamicharts
  chartName: nginx
  version: "18.2.5"
  releaseName: nginx
  namespace: nginx
  options:
    waitForJobs: true
    atomic: true
    wait: true
    timeout: 5m
    install:
      createNamespace: true
  valuesTemplate: |-
    service:
      type: NodePort
```

Deploy and verify:

```bash
# Deploy nginx
kubectl apply -f helm-chart-proxy-nginx.yaml

# Wait for HelmReleaseProxy to be ready
kubectl wait --for=condition=Ready --timeout=300s helmreleaseproxy --all

# Check pods on muscat
kubectl --kubeconfig=muscat-kubeconfig.yaml get pods -n nginx

# Check pods on delaware
kubectl --kubeconfig=delaware-kubeconfig.yaml get pods -n nginx

# Check services
kubectl --kubeconfig=muscat-kubeconfig.yaml get svc -n nginx
kubectl --kubeconfig=delaware-kubeconfig.yaml get svc -n nginx
```

Cleanup:

```bash
kubectl delete -f helm-chart-proxy-nginx.yaml
```

### Deploy to Specific Clusters

Create a HelmChartProxy that uses cluster labels:

```yaml
# helm-chart-proxy-nginx.yaml
apiVersion: addons.cluster.x-k8s.io/v1alpha1
kind: HelmChartProxy
metadata:
  name: nginx
spec:
  clusterSelector:
    matchLabels:
      use-nginx: "true"  # Only deploy to clusters with this label
  repoURL: oci://registry-1.docker.io/bitnamicharts
  chartName: nginx
  version: "18.2.5"
  releaseName: nginx
  namespace: nginx
  options:
    waitForJobs: true
    atomic: true
    wait: true
    timeout: 5m
    install:
      createNamespace: true
  valuesTemplate: |-
    service:
      type: NodePort
```

Deploy and verify:

```bash
# Deploy nginx
kubectl apply -f helm-chart-proxy-nginx.yaml

# Label only the muscat cluster
kubectl label cluster muscat use-nginx=true

# Wait for HelmReleaseProxy to be ready
kubectl wait --for=condition=Ready --timeout=300s helmreleaseproxy --all

# Check deployment status
kubectl get helmreleaseproxy -A

# Verify nginx is running on muscat
kubectl --kubeconfig=muscat-kubeconfig.yaml get pods -n nginx

# Verify nginx is NOT running on delaware
kubectl --kubeconfig=delaware-kubeconfig.yaml get pods -n nginx
```

Cleanup:

```bash
kubectl delete -f helm-chart-proxy-nginx.yaml
```

### Deploy from Private Registry (GitHub Container Registry)

1. Create a GitHub Personal Access Token with `read:packages` permission

2. Create registry credentials:

```bash
# Create config.json with base64 encoded credentials
echo -n "YOUR_GITHUB_USERNAME:YOUR_GITHUB_TOKEN" | base64 > auth.txt

cat > config.json << EOF
{
  "auths": {
    "ghcr.io": {
      "auth": "$(cat auth.txt)"
    }
  }
}
EOF

# Create secret in caaph-system namespace
kubectl create secret generic github-creds \
  --from-file=config.json \
  -n caaph-system
```

3. Create HelmChartProxy for private chart:

```yaml
# helm-chart-proxy-private.yaml
apiVersion: addons.cluster.x-k8s.io/v1alpha1
kind: HelmChartProxy
metadata:
  name: private-chart
spec:
  clusterSelector: {}
  repoURL: oci://ghcr.io/YOUR_GITHUB_USERNAME
  chartName: YOUR_CHART_NAME
  version: "0.1.0"
  releaseName: private-chart
  namespace: YOUR_NAMESPACE
  credentials:
    secret:
      name: github-creds
      namespace: caaph-system
    key: config.json
  options:
    waitForJobs: true
    atomic: true
    wait: true
    timeout: 5m
    install:
      createNamespace: true
```

Deploy and verify:

```bash
# Deploy chart
kubectl apply -f helm-chart-proxy-private.yaml

# Wait for HelmReleaseProxy to be ready
kubectl wait --for=condition=Ready --timeout=300s helmreleaseproxy --all

# Check status
kubectl get helmchartproxy private-chart -o yaml

# List releases on both clusters
helm --kubeconfig=muscat-kubeconfig.yaml list -A
helm --kubeconfig=delaware-kubeconfig.yaml list -A
```

Cleanup:

```bash
kubectl delete -f helm-chart-proxy-private.yaml
```