setup:
	k3d cluster create --config cluster.yaml
	helmfile sync --wait

install-kubernetes-provider:
	kubectl apply -f provider-kubernetes.yaml

setup-kubernetes-provider-config:
	#!/usr/bin/env bash
	set -eux
	SA=$(kubectl -n crossplane-system get sa -o name | grep provider-kubernetes | sed -e 's|serviceaccount\/|crossplane-system:|g')
	kubectl create clusterrolebinding provider-kubernetes-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}"

install-github-provider:
	kubectl apply -f provider-github.yaml

setup-for-github-personal:
	#!/usr/bin/env bash
	[[ -f github-credentials/personal.yaml ]] || {
		gum format -- 'Please copy `github-credentials/personal.template.yaml` to create `github-credentials/personal.yaml` and fill in the values.'
		exit 1
	}
	set -eux
	JSON=$(yq 'omit(["$schema"])' github-credentials/personal.yaml -o=json -I=0)
	kubectl create secret generic github-personal --from-literal=credentials="${JSON}"
	kubectl apply -f provider-github-personal-config.yaml

setup-for-github-app:
	#!/usr/bin/env bash
	[[ -f github-credentials/github-app.yaml ]] || {
		gum format -- 'Please copy `github-credentials/github-app.template.yaml` to create `github-credentials/github-app.yaml` and fill in the values.'
		exit 1
	}
	set -eux
	JSON=$(yq 'omit(["$schema"])' github-credentials/github-app.yaml -o=json -I=0)
	kubectl create secret generic github-app --from-literal=credentials="${JSON}"
	kubectl apply -f provider-github-app-config.yaml

download-crds:
	#!/usr/bin/env bash
	kubectl get crd -o custom-columns=NAME:.metadata.name | grep -E "suin.jp|github.upbound.io" | while read -r crd; do
		kubectl get crd "$crd" -o yaml > "crds/${crd}.yaml"
	done

teardown:
	k3d cluster delete --config cluster.yaml
