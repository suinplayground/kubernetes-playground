#!/usr/bin/env zsh
PS4='%F{blue}RUN%f '
set -euxo pipefail
helmfile sync --wait
kubectl apply -f 01-providers.yaml
kubectl wait --for=condition=Healthy=true provider.pkg.crossplane.io/provider-kubernetes
kubectl apply -f 02-providers-config.yaml
kubectl apply -f 03-functions.yaml
kubectl wait --for=condition=Healthy=true function.pkg.crossplane.io/function-patch-and-transform
kubectl apply -f 04-xrd.yaml
kubectl apply -f 05-composition.yaml
kubectl apply -f 06-xr.yaml
kubectl wait --for=condition=Ready=true xtext.demo07.suin.jp/demo07-xtext
kubectl get configmaps
kubectl get secrets
: 🎉 ConfigMap and Secret are created successfully.
