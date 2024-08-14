#!/usr/bin/env zsh
PS4='%F{blue}RUN%f '
set -euo pipefail
kubectl get secret github-personal > /dev/null 2>&1 || {
	[[ -f personal.yaml ]] || {
		gum format -- 'Please copy `personal.template.yaml` to create `personal.yaml` and fill in the values.'
		exit 1
	}
	JSON=$(yq personal.yaml -o=json -I=0)
  kubectl create secret generic github-personal --from-literal=credentials="${JSON}"
}
set -x
helmfile sync --wait
kubectl apply -f 01-providers.yaml
kubectl wait --for=condition=Healthy=true provider.pkg.crossplane.io/provider-github
kubectl apply -f 02-providers-config.yaml
kubectl apply -f 03-managed-resources.yaml
kubectl wait --for=condition=Ready=true repositories.repo.github.upbound.io/demo04-repo
kubectl get repositories.repo.github.upbound.io/demo04-repo -o yaml | yq .status.atProvider
: 🎉 GitHub repository demo04-repo is created successfully.
