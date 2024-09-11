#!/usr/bin/env zsh
PS4='%F{blue}⦿%f '
set -euxo pipefail

: Install the Helm charts
helmfile sync --wait

: Install the Crossplane composite functions
kcl run 01-functions.k | kubectl apply -f -

: Wait for the functions to be ready
kubectl wait --for=condition=Healthy=true function.pkg.crossplane.io/function-kcl
kubectl wait --for=condition=Healthy=true function.pkg.crossplane.io/function-auto-ready
kubectl wait --for=condition=Healthy=true function.pkg.crossplane.io/function-extra-resources

: Install the Crossplane composite resources defnitions
kcl run 02-xrds.k | kubectl apply -f -

: Wait for the resources to be ready
kubectl wait --for=condition=Established=true compositeresourcedefinitions.apiextensions.crossplane.io/xr1.suin.jp
kubectl wait --for=condition=Established=true compositeresourcedefinitions.apiextensions.crossplane.io/xr2.suin.jp

: Install the Crossplane compositions
kcl run 03-compositions.k | kubectl apply -f -

: Create the Crossplane composite resources
kcl run 04-xrs.k | kubectl apply -f -

: Wait for the resources to be ready
kubectl wait --for=condition=Ready=true xr1.suin.jp/object1

: Look into the function logs
kubectl logs -n crossplane-system -f $(kubectl get pods -o name -n crossplane-system | grep function-kcl) --since 1s

