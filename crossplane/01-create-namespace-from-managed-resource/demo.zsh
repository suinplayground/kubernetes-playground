#!/usr/bin/env zsh
PS4='%F{blue}RUN%f '
set -euxo pipefail
helmfile sync --wait
kubectl apply -f 01-providers.yaml
kubectl wait --for=condition=Healthy=true provider.pkg.crossplane.io/provider-kubernetes
kubectl apply -f 02-roles.yaml
set +x
SA=$(kubectl -n crossplane-system get sa -o name | grep provider-kubernetes | sed -e 's|serviceaccount/||g')
set -x
:
: The default permissions assigned to provider-kubernetes are as follows.
: Since there are no permissions related to namespaces, you need to add permissions to create namespaces.
:
kubectl describe clusterroles crossplane:provider:${SA}:system
kubectl create clusterrolebinding demo01-provider-kubernetes-namespace-to-manage --clusterrole demo01-namespace-to-manage --serviceaccount="crossplane-system:${SA}"
kubectl apply -f 03-providers-config.yaml
kubectl apply -f 04-managed-resources.yaml
kubectl wait --for=condition=Ready=true objects.kubernetes.crossplane.io/demo01-namespace
kubectl get namespaces
: 🎉 Namespace demo01-namespace is created successfully.
