# Envoy Gateway: GatewayNamespace Mode Fails to Handle Gateways Across Multiple Namespaces

## Overview of GatewayNamespace Mode

The GatewayNamespace mode is a beta feature of Envoy Gateway that allows the system to create Envoy Proxy Deployments/Services in the same namespace as the Gateway resource. This is in contrast to the default ControllerNamespace mode, where all Envoy Pods are aggregated in the controller's own namespace (e.g., `envoy-gateway-system`). The GatewayNamespace mode is designed to allow teams or tenants to use Gateway API while maintaining network boundary isolation.

## Problem Description

When using GatewayNamespace mode with multiple Gateway resources across different namespaces, the Envoy Gateway controller incorrectly creates Envoy Proxy Deployments/Services for all Gateways in the first namespace it processes, rather than in their respective namespaces as expected. This leads to a situation where resources from one namespace are incorrectly deployed into another namespace, breaking the isolation that GatewayNamespace mode is intended to provide.

## Environment

- Kubernetes: Kind v1.32.2
- Gateway API: v1.2.0
- Cert Manager: v1.17.1
- Envoy Gateway: v0.0.0-latest (2025-05-08)
- Tools:
  - kubectl: v1.32.3
  - helm: v3.17.3
  - kind: v0.27.0

## Reproduction Steps

This issue can be reproduced by creating Gateway resources in multiple namespaces while running Envoy Gateway in GatewayNamespace mode.

### Detailed setup procedure

<details>
<summary>Click to expand detailed steps</summary>

1. Create a Kind cluster
   ```bash
   kind create cluster
   ```

2. Install Gateway API CRDs
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
   ```

3. Install cert-manager
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.1/cert-manager.yaml
   kubectl wait --for=condition=available --timeout=60s deployment/cert-manager -n cert-manager
   kubectl wait --for=condition=available --timeout=60s deployment/cert-manager-webhook -n cert-manager
   kubectl wait --for=condition=available --timeout=60s deployment/cert-manager-cainjector -n cert-manager
   ```

4. Install Envoy Gateway with GatewayNamespace mode
   ```bash
   helm install eg oci://docker.io/envoyproxy/gateway-helm \
     --version v0.0.0-latest \
     -n envoy-gateway-system \
     --create-namespace \
     --set config.envoyGateway.provider.kubernetes.deploy.type=GatewayNamespace
   kubectl wait --for=condition=available --timeout=600s deployment/envoy-gateway -n envoy-gateway-system
   ```

5. Create GatewayClass
   ```bash
   kubectl apply -f - <<EOF
   apiVersion: gateway.networking.k8s.io/v1
   kind: GatewayClass
   metadata:
     name: eg
   spec:
     controllerName: gateway.envoyproxy.io/gatewayclass-controller
   EOF
   kubectl wait --for=condition=accepted --timeout=60s gatewayclass/eg
   ```

6. Create test namespaces
   ```bash
   kubectl apply -f - <<EOF
   apiVersion: v1
   kind: Namespace
   metadata:
     name: ns1
   ---
   apiVersion: v1
   kind: Namespace
   metadata:
     name: ns2
   EOF
   kubectl wait --for=jsonpath='{.status.phase}'=Active --timeout=60s namespace/ns1
   kubectl wait --for=jsonpath='{.status.phase}'=Active --timeout=60s namespace/ns2
   ```

7. Create Gateway resources in different namespaces
   ```bash
   kubectl apply -f - <<EOF
   apiVersion: gateway.networking.k8s.io/v1
   kind: Gateway
   metadata:
     name: eg
     namespace: ns1
   spec:
     gatewayClassName: eg
     listeners:
       - name: http
         protocol: HTTP
         port: 80
   ---
   apiVersion: gateway.networking.k8s.io/v1
   kind: Gateway
   metadata:
     name: eg
     namespace: ns2
   spec:
     gatewayClassName: eg
     listeners:
       - name: http
         protocol: HTTP
         port: 80
   EOF
   ```

8. Wait for resources to be created
   ```bash
   sleep 30
   ```

9. Check Gateway status
   ```bash
   kubectl get gateway -A
   ```

10. Check where Deployments and Services were created
    ```bash
    kubectl get deployment -n ns1
    kubectl get deployment -n ns2
    kubectl get service -n ns1
    kubectl get service -n ns2
    ```

</details>

## Expected Behavior

When using GatewayNamespace mode, each Gateway resource should have its corresponding Envoy Proxy Deployment and Service created in the same namespace as the Gateway resource. Specifically:

- For the Gateway in namespace `ns1`, an Envoy Proxy Deployment and Service should be created in namespace `ns1`.
- For the Gateway in namespace `ns2`, an Envoy Proxy Deployment and Service should be created in namespace `ns2`.

This would maintain proper namespace isolation between resources.

## Actual Behavior

All Envoy Proxy resources are incorrectly created in the first namespace (`ns1`), regardless of which namespace the Gateway resource belongs to:

```
kubectl get deployment -n ns1
NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
envoy-ns1-eg-ccb6ad73   1/1     1            1           7m55s
envoy-ns2-eg-341c9697   1/1     1            1           7m55s

kubectl get deployment -n ns2
No resources found in ns2 namespace.

kubectl get service -n ns1
NAME                    TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
envoy-ns1-eg-ccb6ad73   LoadBalancer   10.96.221.153   <pending>     80:30967/TCP   5m49s
envoy-ns2-eg-341c9697   LoadBalancer   10.96.182.98    <pending>     80:32101/TCP   5m49s

kubectl get service -n ns2
No resources found in ns2 namespace.
```

Note that the deployment `envoy-ns2-eg-341c9697` and service `envoy-ns2-eg-341c9697` are incorrectly created in namespace `ns1` instead of `ns2`. This violates the namespace isolation principle of the GatewayNamespace mode.

The controller logs show that it recognizes Gateways in both namespaces, but it fails to create the Envoy resources in the correct namespace:

```
INFO    provider        kubernetes/controller.go:1017   processing Gateway      {"runner": "provider", "namespace": "ns1", "name": "eg"}
INFO    provider        kubernetes/controller.go:1017   processing Gateway      {"runner": "provider", "namespace": "ns2", "name": "eg"}
```

<details>
<summary>Click to expand controller logs</summary>

```
kubectl logs deployment/envoy-gateway -n envoy-gateway-system
2025-05-07T23:50:00.562Z        INFO    config-loader   loader/configloader.go:106      running hook
2025-05-07T23:50:00.562Z        INFO    config-loader   loader/configloader.go:48       watching for changes to the EnvoyGateway configuration  {"path": "/config/envoy-gateway.yaml"}
2025-05-07T23:50:00.562Z        INFO    admin   admin/server.go:34      starting admin server   {"address": "127.0.0.1:19000", "enablePprof": false}
2025-05-07T23:50:00.562Z        INFO    metrics metrics/register.go:179 initialized metrics pull endpoint       {"address": "0.0.0.0:19001", "endpoint": "/metrics"}
2025-05-07T23:50:00.562Z        INFO    metrics metrics/register.go:62  starting metrics server {"address": "0.0.0.0:19001"}
2025-05-07T23:50:00.562Z        INFO    cmd/server.go:67        Start runners
2025-05-07T23:50:00.563Z        INFO    cmd/server.go:279       Starting runner {"name": "provider"}
2025-05-07T23:50:00.565Z        INFO    provider.controller-runtime.webhook     webhook/server.go:183   Registering webhook     {"runner": "provider", "path": "/inject-pod-topology"}
2025-05-07T23:50:00.565Z        INFO    provider        kubernetes/controller.go:141    created gatewayapi controller   {"runner": "provider"}
2025-05-07T23:50:00.578Z        INFO    provider        kubernetes/controller.go:1469   ServiceImport CRD not found, skipping ServiceImport watch{"runner": "provider"}
2025-05-07T23:50:00.586Z        INFO    provider        kubernetes/controller.go:1823   Watching gatewayAPI related objects     {"runner": "provider"}
2025-05-07T23:50:00.587Z        INFO    provider        runner/runner.go:66     Running provider        {"runner": "provider", "type": "Kubernetes"}
2025-05-07T23:50:00.587Z        INFO    cmd/server.go:279       Starting runner {"name": "gateway-api"}
2025-05-07T23:50:00.587Z        INFO    gateway-api     runner/runner.go:91     started {"runner": "gateway-api"}
2025-05-07T23:50:00.587Z        INFO    cmd/server.go:279       Starting runner {"name": "xds-translator"}
2025-05-07T23:50:00.587Z        INFO    xds-translator  runner/runner.go:53     started {"runner": "xds-translator"}
2025-05-07T23:50:00.587Z        INFO    cmd/server.go:279       Starting runner {"name": "infrastructure"}
2025-05-07T23:50:00.587Z        INFO    cmd/server.go:279       Starting runner {"name": "xds-server"}
2025-05-07T23:50:00.587Z        INFO    xds-server      runner/runner.go:98     loaded TLS certificate and key  {"runner": "xds-server"}
2025-05-07T23:50:00.588Z        INFO    xds-server      runner/runner.go:110    gatewayNamespaceMode is enabled, setting up JWTAuthInterceptor and sTLS server    {"runner": "xds-server"}
2025-05-07T23:50:00.588Z        INFO    provider.controller-runtime.metrics     server/server.go:208    Starting metrics server {"runner": "provider"}
2025-05-07T23:50:00.588Z        INFO    provider.controller-runtime.metrics     server/server.go:247    Serving metrics server  {"runner": "provider", "bindAddress": ":8080", "secure": false}
2025-05-07T23:50:00.588Z        INFO    provider        manager/server.go:83    starting server {"runner": "provider", "name": "health probe", "addr": "[::]:8081"}
2025-05-07T23:50:00.588Z        INFO    provider.controller-runtime.webhook     webhook/server.go:191   Starting webhook server {"runner": "provider"}
2025-05-07T23:50:00.588Z        INFO    xds-server      runner/runner.go:148    started {"runner": "xds-server"}
2025-05-07T23:50:00.588Z        INFO    provider.controller-runtime.certwatcher certwatcher/certwatcher.go:211  Updated current TLS certificate {"runner": "provider"}
2025-05-07T23:50:00.588Z        INFO    provider.controller-runtime.webhook     webhook/server.go:242   Serving webhook server  {"runner": "provider", "host": "", "port": 9443}
2025-05-07T23:50:00.588Z        INFO    provider.controller-runtime.certwatcher certwatcher/certwatcher.go:133  Starting certificate poll+watcher{"runner": "provider", "interval": "10s"}
2025-05-07T23:50:00.591Z        INFO    wasm-cache      wasm/httpserver.go:111  Listening on :18002
2025-05-07T23:50:00.791Z        INFO    provider        controller/controller.go:204    Starting EventSource    {"runner": "provider", "controller": "gatewayapi-1746661800", "source": "kind source: *v1alpha1.HTTPRouteFilter"}
2025-05-07T23:50:00.791Z        INFO    provider        leaderelection/leaderelection.go:257    attempting to acquire leader lease envoy-gateway-system/5b9825d2.gateway.envoyproxy.io... {"runner": "provider"}
2025-05-07T23:50:00.791Z        INFO    provider        controller/controller.go:204    Starting EventSource    {"runner": "provider", "controller": "gatewayapi-1746661800", "source": "*kubernetes.watchAndReconcileSource"}
2025-05-07T23:50:00.791Z        INFO    provider        controller/controller.go:204    Starting EventSource    {"runner": "provider", "controller": "gatewayapi-1746661800", "source": "kind source: *v1.GatewayClass"}
2025-05-07T23:50:00.791Z        INFO    provider        controller/controller.go:204    Starting EventSource    {"runner": "provider", "controller": "gatewayapi-1746661800", "source": "kind source: *v1alpha1.EnvoyProxy"}
2025-05-07T23:50:00.791Z        INFO    provider        controller/controller.go:204    Starting EventSource    {"runner": "provider", "controller": "gatewayapi-1746661800", "source": "kind source: *v1.Gateway"}
2025-05-07T23:50:00.791Z        INFO    provider        controller/controller.go:204    Starting EventSource    {"runner": "provider", "controller": "gatewayapi-1746661800", "source": "kind source: *v1.HTTPRoute"}
2025-05-07T23:50:00.791Z        INFO    provider        controller/controller.go:204    Starting EventSource    {"runner": "provider", "controller": "gatewayapi-1746661800", "source": "kind source: *v1.GRPCRoute"}
2025-05-07T23:50:00.791Z        INFO    provider        controller/controller.go:204    Starting EventSource    {"runner": "provider", "controller": "gatewayapi-1746661800", "source": "kind source: *v1alpha2.TLSRoute"}
2025-05-07T23:50:00.791Z        INFO    provider        controller/controller.go:204    Starting EventSource    {"runner": "provider", "controller": "gatewayapi-1746661800", "source": "kind source: *v1alpha2.UDPRoute"}
2025-05-07T23:50:00.791Z        INFO    provider        controller/controller.go:204    Starting EventSource    {"runner": "provider", "controller": "gatewayapi-1746661800", "source": "kind source: *v1alpha2.TCPRoute"}
2025-05-07T23:50:00.791Z        INFO    provider        controller/controller.go:204    Starting EventSource    {"runner": "provider", "controller": "gatewayapi-1746661800", "source": "kind source: *v1.Service"}
2025-05-07T23:50:00.791Z        INFO    provider        controller/controller.go:204    Starting EventSource    {"runner": "provider", "controller": "gatewayapi-1746661800", "source": "kind source: *v1.EndpointSlice"}
2025-05-07T23:50:00.791Z        INFO    provider        controller/controller.go:204    Starting EventSource    {"runner": "provider", "controller": "gatewayapi-1746661800", "source": "kind source: *v1.Node"}
2025-05-07T23:50:00.791Z        INFO    provider        controller/controller.go:204    Starting EventSource    {"runner": "provider", "controller": "gatewayapi-1746661800", "source": "kind source: *v1.Secret"}
2025-05-07T23:50:00.791Z        INFO    provider        controller/controller.go:204    Starting EventSource    {"runner": "provider", "controller": "gatewayapi-1746661800", "source": "kind source: *v1.ConfigMap"}
2025-05-07T23:50:00.791Z        INFO    provider        controller/controller.go:204    Starting EventSource    {"runner": "provider", "controller": "gatewayapi-1746661800", "source": "kind source: *v1beta1.ReferenceGrant"}
2025-05-07T23:50:00.791Z        INFO    provider        controller/controller.go:204    Starting EventSource    {"runner": "provider", "controller": "gatewayapi-1746661800", "source": "kind source: *v1.Deployment"}
2025-05-07T23:50:00.791Z        INFO    provider        controller/controller.go:204    Starting EventSource    {"runner": "provider", "controller": "gatewayapi-1746661800", "source": "kind source: *v1.DaemonSet"}
2025-05-07T23:50:00.791Z        INFO    provider        controller/controller.go:204    Starting EventSource    {"runner": "provider", "controller": "gatewayapi-1746661800", "source": "kind source: *v1alpha1.ClientTrafficPolicy"}
2025-05-07T23:50:00.791Z        INFO    provider        controller/controller.go:204    Starting EventSource    {"runner": "provider", "controller": "gatewayapi-1746661800", "source": "kind source: *v1alpha1.BackendTrafficPolicy"}
2025-05-07T23:50:00.791Z        INFO    provider        controller/controller.go:204    Starting EventSource    {"runner": "provider", "controller": "gatewayapi-1746661800", "source": "kind source: *v1alpha1.SecurityPolicy"}
2025-05-07T23:50:00.792Z        INFO    provider        controller/controller.go:204    Starting EventSource    {"runner": "provider", "controller": "gatewayapi-1746661800", "source": "kind source: *v1alpha3.BackendTLSPolicy"}
2025-05-07T23:50:00.792Z        INFO    provider        controller/controller.go:204    Starting EventSource    {"runner": "provider", "controller": "gatewayapi-1746661800", "source": "kind source: *v1alpha1.EnvoyExtensionPolicy"}
2025-05-07T23:50:00.796Z        INFO    provider        leaderelection/leaderelection.go:271    successfully acquired lease envoy-gateway-system/5b9825d2.gateway.envoyproxy.io   {"runner": "provider"}
2025-05-07T23:50:00.796Z        INFO    provider        kubernetes/status_updater.go:134        started status update handler   {"runner": "provider"}
2025-05-07T23:50:00.796Z        INFO    infrastructure  runner/runner.go:75     started {"runner": "infrastructure"}
2025-05-07T23:50:00.802Z        ERROR   infrastructure  runner/runner.go:71     failed to delete ratelimit infra        {"runner": "infrastructure", "error": "failed to delete serviceaccount /envoy-ratelimit: the server does not allow this method on the requested resource"}
2025-05-07T23:50:00.895Z        INFO    provider        controller/controller.go:239    Starting Controller     {"runner": "provider", "controller": "gatewayapi-1746661800"}
2025-05-07T23:50:00.895Z        INFO    provider        controller/controller.go:248    Starting workers        {"runner": "provider", "controller": "gatewayapi-1746661800", "worker count": 1}
2025-05-07T23:50:00.895Z        INFO    provider        kubernetes/controller.go:190    reconciling gateways    {"runner": "provider"}
2025-05-07T23:50:00.895Z        INFO    provider        kubernetes/controller.go:201    no accepted gatewayclass        {"runner": "provider"}
2025-05-07T23:50:38.089Z        INFO    provider        kubernetes/predicates.go:41     gatewayclass has matching controller name, processing   {"runner": "provider", "name": "eg"}
2025-05-07T23:50:38.089Z        INFO    provider        kubernetes/controller.go:190    reconciling gateways    {"runner": "provider"}
2025-05-07T23:50:38.191Z        INFO    provider        kubernetes/controller.go:719    processing OIDC HMAC Secret     {"runner": "provider", "namespace": "envoy-gateway-system", "name": "envoy-oidc-hmac"}
2025-05-07T23:50:38.293Z        INFO    provider        kubernetes/controller.go:329    No gateways found for accepted gatewayclass     {"runner": "provider"}
2025-05-07T23:50:38.293Z        INFO    provider        kubernetes/controller.go:353    reconciled gateways successfully        {"runner": "provider"}
2025-05-07T23:50:38.294Z        INFO    gateway-api     runner/runner.go:129    received an update      {"runner": "gateway-api"}
2025-05-07T23:50:38.294Z        INFO    provider        kubernetes/status_updater.go:145        received a status update        {"runner": "provider", "namespace": "", "name": "eg"}
2025-05-07T23:50:38.898Z        INFO    provider        kubernetes/controller.go:190    reconciling gateways    {"runner": "provider"}
2025-05-07T23:50:38.898Z        INFO    provider        kubernetes/controller.go:1017   processing Gateway      {"runner": "provider", "namespace": "ns1", "name": "eg"}
2025-05-07T23:50:38.898Z        INFO    provider        kubernetes/controller.go:719    processing OIDC HMAC Secret     {"runner": "provider", "namespace": "envoy-gateway-system", "name": "envoy-oidc-hmac"}
2025-05-07T23:50:39.005Z        INFO    provider        kubernetes/status_updater.go:145        received a status update        {"runner": "provider", "namespace": "", "name": "eg"}
2025-05-07T23:50:39.005Z        INFO    provider.eg     kubernetes/status_updater.go:109        status unchanged, bypassing update      {"runner": "provider"}
2025-05-07T23:50:39.012Z        INFO    provider.KubeAPIWarningLogger   log/warning_handler.go:65       metadata.finalizers: "gateway-exists-finalizer.gateway.networking.k8s.io": prefer a domain-qualified finalizer name including a path (/) to avoid accidental conflicts with other finalizer writers {"runner": "provider"}
2025-05-07T23:50:39.012Z        INFO    provider        kubernetes/controller.go:353    reconciled gateways successfully        {"runner": "provider"}
2025-05-07T23:50:39.012Z        INFO    provider        kubernetes/controller.go:190    reconciling gateways    {"runner": "provider"}
2025-05-07T23:50:39.012Z        INFO    provider        kubernetes/controller.go:1017   processing Gateway      {"runner": "provider", "namespace": "ns1", "name": "eg"}
2025-05-07T23:50:39.012Z        INFO    provider        kubernetes/controller.go:1017   processing Gateway      {"runner": "provider", "namespace": "ns2", "name": "eg"}
2025-05-07T23:50:39.013Z        INFO    provider        kubernetes/controller.go:719    processing OIDC HMAC Secret     {"runner": "provider", "namespace": "envoy-gateway-system", "name": "envoy-oidc-hmac"}
2025-05-07T23:50:39.013Z        INFO    gateway-api     runner/runner.go:129    received an update      {"runner": "gateway-api"}
2025-05-07T23:50:39.013Z        INFO    provider        kubernetes/controller.go:353    reconciled gateways successfully        {"runner": "provider"}
2025-05-07T23:50:39.015Z        INFO    infrastructure  runner/runner.go:100    received an update      {"runner": "infrastructure"}
2025-05-07T23:50:39.015Z        INFO    gateway-api     runner/runner.go:129    received an update      {"runner": "gateway-api"}
2025-05-07T23:50:39.015Z        INFO    xds-translator  runner/runner.go:61     received an update      {"runner": "xds-translator"}
2025-05-07T23:50:39.016Z        INFO    provider        kubernetes/status_updater.go:145        received a status update        {"runner": "provider", "namespace": "ns1", "name": "eg"}
2025-05-07T23:50:39.018Z        INFO    xds-translator  runner/runner.go:61     received an update      {"runner": "xds-translator"}
2025-05-07T23:50:39.019Z        INFO    xds-server      runner/runner.go:194    received an update      {"runner": "xds-server"}
2025-05-07T23:50:39.019Z        INFO    xds-server      runner/runner.go:194    received an update      {"runner": "xds-server"}
2025-05-07T23:50:39.021Z        INFO    provider        kubernetes/status_updater.go:145        received a status update        {"runner": "provider", "namespace": "ns1", "name": "eg"}
2025-05-07T23:50:39.034Z        INFO    provider.eg.ns1 kubernetes/status_updater.go:109        status unchanged, bypassing update      {"runner": "provider"}
2025-05-07T23:50:39.034Z        INFO    provider        kubernetes/status_updater.go:145        received a status update        {"runner": "provider", "namespace": "ns2", "name": "eg"}
2025-05-07T23:50:39.039Z        INFO    provider        kubernetes/status_updater.go:145        received a status update        {"runner": "provider", "namespace": "ns1", "name": "eg"}
2025-05-07T23:50:39.039Z        INFO    provider.eg.ns1 kubernetes/status_updater.go:109        status unchanged, bypassing update      {"runner": "provider"}
2025-05-07T23:50:39.040Z        INFO    provider        kubernetes/status_updater.go:145        received a status update        {"runner": "provider", "namespace": "ns1", "name": "eg"}
2025-05-07T23:50:39.041Z        INFO    provider.eg.ns1 kubernetes/status_updater.go:109        status unchanged, bypassing update      {"runner": "provider"}
2025-05-07T23:50:39.047Z        INFO    provider        kubernetes/status_updater.go:145        received a status update        {"runner": "provider", "namespace": "ns1", "name": "eg"}
2025-05-07T23:50:39.053Z        INFO    provider        kubernetes/status_updater.go:145        received a status update        {"runner": "provider", "namespace": "ns1", "name": "eg"}
2025-05-07T23:50:39.058Z        INFO    infrastructure  runner/runner.go:100    received an update      {"runner": "infrastructure"}
2025-05-07T23:50:39.061Z        INFO    provider        kubernetes/status_updater.go:145        received a status update        {"runner": "provider", "namespace": "ns1", "name": "eg"}
2025-05-07T23:50:39.065Z        INFO    provider        kubernetes/status_updater.go:145        received a status update        {"runner": "provider", "namespace": "ns2", "name": "eg"}
2025-05-07T23:50:39.066Z        INFO    provider.eg.ns2 kubernetes/status_updater.go:109        status unchanged, bypassing update      {"runner": "provider"}
2025-05-07T23:50:39.071Z        INFO    provider        kubernetes/status_updater.go:145        received a status update        {"runner": "provider", "namespace": "ns2", "name": "eg"}
2025-05-07T23:50:39.071Z        INFO    provider.eg.ns2 kubernetes/status_updater.go:109        status unchanged, bypassing update      {"runner": "provider"}
2025-05-07T23:50:39.079Z        INFO    provider        kubernetes/status_updater.go:145        received a status update        {"runner": "provider", "namespace": "ns2", "name": "eg"}
2025-05-07T23:50:39.079Z        INFO    provider.eg.ns2 kubernetes/status_updater.go:109        status unchanged, bypassing update      {"runner": "provider"}
2025-05-07T23:50:39.084Z        INFO    provider        kubernetes/status_updater.go:145        received a status update        {"runner": "provider", "namespace": "ns2", "name": "eg"}
2025-05-07T23:50:39.084Z        INFO    provider.eg.ns2 kubernetes/status_updater.go:109        status unchanged, bypassing update      {"runner": "provider"}
2025-05-07T23:50:39.118Z        INFO    provider        kubernetes/status_updater.go:145        received a status update        {"runner": "provider", "namespace": "ns2", "name": "eg"}
2025-05-07T23:50:39.118Z        INFO    provider.eg.ns2 kubernetes/status_updater.go:109        status unchanged, bypassing update      {"runner": "provider"}
2025-05-07T23:50:48.097Z        INFO    xds-server      v3/simple.go:569        open delta watch ID:1 for type.googleapis.com/envoy.config.cluster.v3.Cluster Resources:map[] from nodeID: "envoy-ns1-eg-ccb6ad73-6cbf5868cc-dmssd",  version ""
2025-05-07T23:50:48.097Z        INFO    xds-server      v3/simple.go:569        open delta watch ID:2 for type.googleapis.com/envoy.config.listener.v3.Listener Resources:map[] from nodeID: "envoy-ns1-eg-ccb6ad73-6cbf5868cc-dmssd",  version "1"
2025-05-07T23:50:48.098Z        INFO    xds-server      v3/simple.go:569        open delta watch ID:3 for type.googleapis.com/envoy.config.route.v3.RouteConfiguration Resources:map[ns1/eg/http:{}] from nodeID: "envoy-ns1-eg-ccb6ad73-6cbf5868cc-dmssd",  version "1"
2025-05-07T23:50:49.520Z        INFO    provider        kubernetes/status_updater.go:145        received a status update        {"runner": "provider", "namespace": "ns1", "name": "eg"}
2025-05-07T23:50:50.076Z        INFO    xds-server      v3/simple.go:569        open delta watch ID:4 for type.googleapis.com/envoy.config.cluster.v3.Cluster Resources:map[] from nodeID: "envoy-ns2-eg-341c9697-5558ccd87-mqtq8",  version ""
2025-05-07T23:50:50.078Z        INFO    xds-server      v3/simple.go:569        open delta watch ID:5 for type.googleapis.com/envoy.config.listener.v3.Listener Resources:map[] from nodeID: "envoy-ns2-eg-341c9697-5558ccd87-mqtq8",  version "2"
2025-05-07T23:50:50.079Z        INFO    xds-server      v3/simple.go:569        open delta watch ID:6 for type.googleapis.com/envoy.config.route.v3.RouteConfiguration Resources:map[ns2/eg/http:{}] from nodeID: "envoy-ns2-eg-341c9697-5558ccd87-mqtq8",  version "2"
2025-05-07T23:51:00.554Z        INFO    provider        kubernetes/status_updater.go:145        received a status update        {"runner": "provider", "namespace": "ns2", "name": "eg"}
2025-05-07T23:51:00.554Z        INFO    provider.eg.ns2 kubernetes/status_updater.go:109        status unchanged, bypassing update      {"runner": "provider"}
```

</details>

## Related Issues

- https://github.com/envoyproxy/gateway/issues/2629
  - Closed by https://github.com/envoyproxy/gateway/pull/5137
- https://github.com/envoyproxy/gateway/issues/5864
- https://github.com/envoyproxy/gateway/pull/5937