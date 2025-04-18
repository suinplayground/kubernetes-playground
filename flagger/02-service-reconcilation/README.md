# Flagger Does Not Manage Services with Names Different from Their Deployments

Typically, Flagger creates Services with the same name as their Deployments. If a Service with the same name already exists, Flagger is known to take it under management (making it a reconciliation target) and modify properties like spec.selector.app.

But what happens when a Service is related to a Deployment but has a different name? Will Flagger recognize and manage it, or will it leave it alone? We conducted an investigation to find out.

## Test Environment

- Kubernetes: Kind v1.32.2
- Flagger: v1.41.0
- Gateway API: v1.2.0
- Envoy Gateway: v1.3.2

## Testing Method

1. Set up the test environment
   - Create a Kind cluster
   - Install Gateway API (v1.2.0)
   - Install Cert Manager (v1.17.1)
   - Install Envoy Gateway (v1.3.2)
   - Create GatewayClass and Gateway
   - Install Flagger (v1.41.0)

<details>
<summary>Detailed setup procedure</summary>

1. Create Kind cluster
    ```sh
    kind create cluster
    ```
2. Install Gateway API (v1.2.0)
    ```sh
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
    ```
3. Install Cert Manager (v1.17.1)
    ```sh
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.1/cert-manager.yaml
    kubectl wait --for=condition=available --timeout=60s deployment/cert-manager -n cert-manager
    kubectl wait --for=condition=available --timeout=60s deployment/cert-manager-webhook -n cert-manager
    kubectl wait --for=condition=available --timeout=60s deployment/cert-manager-cainjector -n cert-manager
    ```
4. Install Envoy Gateway (v1.3.2)
    ```sh
    kubectl apply --server-side -f https://github.com/envoyproxy/gateway/releases/download/v1.3.2/install.yaml
    kubectl wait --for=condition=available --timeout=600s deployment/envoy-gateway -n envoy-gateway-system
    ```
5. Create GatewayClass and Gateway
    ```sh
    kubectl apply -f manifests/gatewayclass.yaml
    kubectl wait --for=condition=accepted --timeout=60s gatewayclass/eg
    kubectl apply -f manifests/gateway.yaml
    kubectl wait --for=condition=programmed --timeout=60s gateway/eg
    ```

    #### gatewayclass.yaml
    ```yaml
    apiVersion: gateway.networking.k8s.io/v1
    kind: GatewayClass
    metadata:
    name: eg
    spec:
    controllerName: gateway.envoyproxy.io/gatewayclass-controller
    parametersRef:
        group: gateway.envoyproxy.io
        kind: EnvoyProxy
        name: clusterip-config
        namespace: envoy-gateway-system
    ---
    apiVersion: gateway.envoyproxy.io/v1alpha1
    kind: EnvoyProxy
    metadata:
    name: clusterip-config
    namespace: envoy-gateway-system
    spec:
    provider:
        type: Kubernetes
        kubernetes:
        envoyService:
            type: ClusterIP
    ```

    #### gateway.yaml
    ```yaml
    apiVersion: gateway.networking.k8s.io/v1
    kind: Gateway
    metadata:
    name: eg
    spec:
    gatewayClassName: eg
    listeners:
        - name: http
        protocol: HTTP
        port: 80
    ```
6. Install Flagger (v1.41.0)
    ```sh
    kubectl apply -f https://raw.githubusercontent.com/fluxcd/flagger/v1.41.0/artifacts/flagger/crd.yaml
    kubectl get ns flagger-system || kubectl create ns flagger-system
    helm repo add flagger https://flagger.app
    helm upgrade -i flagger flagger/flagger \
    --version 1.41.0 \
    --namespace flagger-system \
    --set prometheus.install=false \
    --set meshProvider=gatewayapi:v1 \
    --set metricsServer=none
    ```
</details>

2. Deploy the following resources:
   - Deployment name: `podinfo` 
   - Service name: `podinfo-different-name` (different from Deployment name)
   - Canary name: `podinfo` (same as Deployment name)

   ```sh
   kubectl apply -f manifests/deployment.yaml
   kubectl apply -f manifests/service.yaml
   kubectl apply -f manifests/canary.yaml
   ```

   <details>
   <summary>Content of the deployed manifest files</summary>

   ### deployment.yaml
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: podinfo
   spec:
     replicas: 2
     selector:
       matchLabels:
         app: podinfo
     template:
       metadata:
         labels:
           app: podinfo
       spec:
         containers:
         - name: podinfo
           image: stefanprodan/podinfo:latest
           ports:
           - containerPort: 9898
   ```

   ### service.yaml
   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: podinfo-different-name
   spec:
     selector:
       app: podinfo
     ports:
     - port: 9898
       targetPort: 9898
   ```

   ### canary.yaml
   ```yaml
   apiVersion: flagger.app/v1beta1
   kind: Canary
   metadata:
     name: podinfo
   spec:
     targetRef:
       apiVersion: apps/v1
       kind: Deployment
       name: podinfo
     progressDeadlineSeconds: 60
     service:
       port: 9898
       targetPort: 9898
       gatewayRefs:
         - name: eg
           namespace: default
     analysis:
       interval: 1s
       threshold: 5
       maxWeight: 50
       stepWeight: 10
   ```
   </details>

## Test Results

### Services after deployment

```sh
$ kubectl get services
NAME                     TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
kubernetes               ClusterIP   10.96.0.1       <none>        443/TCP    8m30s
podinfo                  ClusterIP   10.96.126.169   <none>        9898/TCP   5m39s
podinfo-canary           ClusterIP   10.96.20.177    <none>        9898/TCP   5m49s
podinfo-different-name   ClusterIP   10.96.141.217   <none>        9898/TCP   6m12s
podinfo-primary          ClusterIP   10.96.130.137   <none>        9898/TCP   5m49s
```

Note: The `podinfo` service (same name as Deployment) is created slightly after the Canary resource is created.

### Original Service (podinfo-different-name)

```yaml
apiVersion: v1
kind: Service
metadata:
  # No ownerReferences - not managed by Flagger
  name: podinfo-different-name
  namespace: default
spec:
  # Selector remains unchanged
  selector:
    app: podinfo
  ports:
  - port: 9898
    targetPort: 9898
```

### podinfo-primary service created by Flagger

```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: podinfo-primary
  name: podinfo-primary
  namespace: default
  ownerReferences:
  - apiVersion: flagger.app/v1beta1
    blockOwnerDeletion: true
    controller: true
    kind: Canary
    name: podinfo
    uid: c388a7b6-6dc9-4aa9-b9f1-e55ad8f31575
spec:
  selector:
    app: podinfo-primary
  ports:
  - name: http
    port: 9898
    targetPort: 9898
```

### podinfo-canary service created by Flagger

```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: podinfo-canary
  name: podinfo-canary
  namespace: default
  ownerReferences:
  - apiVersion: flagger.app/v1beta1
    blockOwnerDeletion: true
    controller: true
    kind: Canary
    name: podinfo
    uid: c388a7b6-6dc9-4aa9-b9f1-e55ad8f31575
spec:
  selector:
    app: podinfo
  ports:
  - name: http
    port: 9898
    targetPort: 9898
```

### Service with the same name as Deployment (podinfo) created by Flagger

```yaml
apiVersion: v1
kind: Service
metadata:
  annotations:
    helm.toolkit.fluxcd.io/driftDetection: disabled
    kustomize.toolkit.fluxcd.io/reconcile: disabled
  labels:
    app: podinfo
  name: podinfo
  namespace: default
  ownerReferences:
  - apiVersion: flagger.app/v1beta1
    blockOwnerDeletion: true
    controller: true
    kind: Canary
    name: podinfo
    uid: c388a7b6-6dc9-4aa9-b9f1-e55ad8f31575
spec:
  selector:
    app: podinfo-primary  # Routes traffic to primary
  ports:
  - name: http
    port: 9898
    targetPort: 9898
```

## Conclusion

Based on our investigation, we confirmed the following:

1. Flagger does not recognize or manage Services with names different from their Deployments
   - The Service `podinfo-different-name`, which has a different name from Deployment `podinfo`, was not controlled or modified by Flagger
2. Flagger creates its own services
   - When deploying a Canary resource, Flagger created the following three Services:
     - `podinfo-primary` - Service that routes traffic to primary version pods
     - `podinfo-canary` - Service that routes traffic to canary version pods
     - `podinfo` - Service with the same name as the Deployment (created slightly later). This receives actual end-user traffic and internally routes to `podinfo-primary`
   - All of these Services are managed by Flagger and have ownerReferences set
3. The original Service remains unchanged
   - The `podinfo-different-name` Service remains in its original state without being modified by Flagger
   - Its selector and other settings remain unchanged
4. Flagger's internal mechanism
   - Flagger creates a service with the same name as the Deployment (`podinfo`) to receive end-user traffic and internally controls traffic between `podinfo-primary` and `podinfo-canary`
   - This control enables canary deployments that gradually shift traffic to the canary version

From this investigation, it is clear that Flagger does not recognize or manage services with names that differ from their deployments. This confirms that creating a Service with a name different from its Deployment is an effective strategy to avoid automatic management by Flagger.
