setup:
	k3d cluster create --config cluster.yaml
	helmfile sync --wait

setup-kubernetes-provider:
	#!/usr/bin/env bash
	set -eux
	kubectl apply -f provider-kubernetes.yaml
	SA=$(kubectl -n crossplane-system get sa -o name | grep provider-kubernetes | sed -e 's|serviceaccount\/|crossplane-system:|g')
	kubectl create clusterrolebinding provider-kubernetes-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}"

teardown:
	k3d cluster delete --config cluster.yaml
