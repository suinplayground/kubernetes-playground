#!/usr/bin/env zsh
PS4='%F{blue}RUN%f '
set -euxo pipefail
helmfile sync --wait
kubectl apply -f 01-providers.yaml
kubectl wait --for=condition=Healthy=true provider.pkg.crossplane.io/provider-kubernetes
kubectl apply -f 02-providers-config.yaml
kubectl apply -f 03-managed-resources.yaml
kubectl wait --for=condition=Ready=true objects.kubernetes.crossplane.io/demo02-config-map
kubectl get configmaps
: 🎉 ConfigMap demo02-config-map is created successfully.
