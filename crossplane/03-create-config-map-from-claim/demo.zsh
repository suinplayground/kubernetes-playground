#!/usr/bin/env zsh
PS4='%F{blue}RUN%f '
set -euxo pipefail
helmfile sync --wait
kubectl apply -f 01-providers.yaml
kubectl wait --for=condition=Healthy=true provider.pkg.crossplane.io/provider-kubernetes
kubectl apply -f 02-providers-config.yaml
kubectl apply -f 03-xrd.yaml
kubectl apply -f 04-composition.yaml
kubectl apply -f 05-claim.yaml
kubectl wait --for=condition=Ready=true configmaps.demo03.suin.jp/demo03-config-map
kubectl get configmaps
: 🎉 ConfigMap demo03-config-map is created successfully.
