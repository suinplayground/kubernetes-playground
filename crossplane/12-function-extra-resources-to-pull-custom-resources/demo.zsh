#!/usr/bin/env zsh
PS4='%F{blue}⦿%f '
set -euxo pipefail

: Install the Helm charts
helmfile sync --wait

: Create a cluster role to allow access to custom resources
kcl run 01-cluster-roles.k | kubectl apply -f -

: Install CRDs
kcl run 02-crds.k | kubectl apply -f -

: Wait for the CRDs to be established
kubectl wait --for=condition=Established=true customresourcedefinition.apiextensions.k8s.io/clusterresources.suin.jp
kubectl wait --for=condition=Established=true customresourcedefinition.apiextensions.k8s.io/namespacedresources.suin.jp

: Install the Crossplane composite functions
kcl run 03-functions.k | kubectl apply -f -

: Wait for the functions to be ready
kubectl wait --for=condition=Healthy=true function.pkg.crossplane.io/function-kcl
kubectl wait --for=condition=Healthy=true function.pkg.crossplane.io/function-auto-ready
kubectl wait --for=condition=Healthy=true function.pkg.crossplane.io/function-extra-resources

: Install the Crossplane composite resources defnitions
kcl run 04-xrds.k | kubectl apply -f -

: Wait for the resources to be ready
kubectl wait --for=condition=Established=true compositeresourcedefinitions.apiextensions.crossplane.io/xr1.suin.jp

: Install the Crossplane compositions
kcl run 05-compositions.k | kubectl apply -f -

: Create a namespace for the resources
kcl run 06-namespace.k | kubectl apply -f -

: Wait for the namespace to be active
kubectl wait --for=jsonpath=status.phase=Active namespace/my-namespace

: Create custom resources
kcl run 07-crs.k | kubectl apply -f -

: Create the Crossplane composite resources
kcl run 08-xrs.k | kubectl apply -f -

: Wait for the resources to be ready
kubectl wait --for=condition=Ready=true xr1.suin.jp/object1

: Look into the function logs
kubectl logs -n crossplane-system -f $(kubectl get pods -o name -n crossplane-system | grep function-kcl) --since 1s

