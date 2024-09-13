#!/usr/bin/env zsh
PS4='%F{blue}⦿%f '
set -euo pipefail

kubectl get secret ghcr-token > /dev/null 2>&1 || {
    gum format -- 'Please create a secret `ghcr-token` before.'
    exit 1
}
set -x

: Install the Helm charts
helmfile sync --wait

: Create a cluster role to allow access to resources outside Crossplane
kcl run setup/cluster_roles | kubectl apply -f -

: Install provider-kubernetes
kcl run setup/provider_kubernetes | kubectl apply -f -

: Wait for provider-kubernetes to be ready
kubectl wait --for=condition=Healthy=true provider.pkg.crossplane.io/provider-kubernetes

: Install provider config for provider-kuberntes
kcl run setup/provider_kubernetes_config | kubectl apply -f -

: Install the Crossplane composite functions
kcl run setup/functions | kubectl apply -f -

: Wait for the functions to be ready
kubectl wait --for=condition=Healthy=true function.pkg.crossplane.io/function-kcl
kubectl wait --for=condition=Healthy=true function.pkg.crossplane.io/function-auto-ready
kubectl wait --for=condition=Healthy=true function.pkg.crossplane.io/function-extra-resources

: Install the Crossplane composite resources defnitions
kcl run component/xrd.k | kubectl apply -f -
kcl run component_version/xrd.k | kubectl apply -f -

: Wait for the resources to be ready
kubectl wait --for=condition=Established=true compositeresourcedefinitions.apiextensions.crossplane.io/xcomponents.appthrust.io
kubectl wait --for=condition=Established=true compositeresourcedefinitions.apiextensions.crossplane.io/xcomponentversions.appthrust.io

: Install the Crossplane compositions
kcl run component_version/composition.k | kubectl apply -f -

: ::: use cases :::

: Connect a image repository to the platform
kcl run usecases/connect_image_repository | kubectl apply -f -

: Wait for the image repository to be connected
kubectl wait --for=condition=Ready=true imagerepositories.image.toolkit.fluxcd.io --all

: The controller creates a new component version
kcl run usecases/create_component_version | kubectl apply -f -

: Wait for the resource to be ready
kubectl wait --for=condition=Ready=true xcomponentversions.appthrust.io --all
