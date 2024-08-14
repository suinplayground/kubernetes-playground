#!/usr/bin/env zsh
PS4='%F{blue}RUN%f '
set -euxo pipefail
helmfile sync --wait
kubectl apply -f 01-providers.yaml
kubectl wait --for=condition=Healthy=true provider.pkg.crossplane.io/provider-kubernetes
kubectl apply -f 02-providers-config.yaml
kubectl apply -f 03-functions.yaml
kubectl wait --for=condition=Healthy=true function.pkg.crossplane.io/function-kcl
kubectl wait --for=condition=Healthy=true function.pkg.crossplane.io/function-auto-ready
kubectl apply -f 04-xrd.yaml
kubectl apply -f 05-composition.yaml
kubectl apply -f 06-xr.yaml
kubectl wait --for=condition=Ready=true xconfigmaps.demo08.suin.jp/demo08-config-map
kubectl get configmaps
: 🎉 ConfigMap is created successfully.
