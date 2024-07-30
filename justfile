setup:
	k3d cluster create --config cluster.yaml
	helmfile sync --wait

setup-kubernetes-provider:
	#!/usr/bin/env bash
	set -eux
	kubectl apply -f provider-kubernetes.yaml
	SA=$(kubectl -n crossplane-system get sa -o name | grep provider-kubernetes | sed -e 's|serviceaccount\/|crossplane-system:|g')
	kubectl create clusterrolebinding provider-kubernetes-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}"

setup-github-provider:
	#!/usr/bin/env bash
	set -eux
	GH_OWNER="$(gum input --header "GitHub organization name")"
	GH_TOKEN="$(gum input --header "GitHub personal access token (Administration=write, Metadata=read)")"
	kubectl create secret generic github-secret --from-literal=credentials="{\"token\":\"${GH_TOKEN}\",\"owner\":\"${GH_OWNER}\"}"
	kubectl apply -f provider-github.yaml
	sleep 5
	kubectl apply -f provider-github-config.yaml

teardown:
	k3d cluster delete --config cluster.yaml
