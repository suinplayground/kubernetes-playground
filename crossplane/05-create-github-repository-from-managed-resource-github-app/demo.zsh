#!/usr/bin/env zsh
PS4='%F{blue}RUN%f '
set -euo pipefail
kubectl get secret github-app > /dev/null 2>&1 || {
	[[ -f github-app.yaml ]] || {
		gum format -- 'Please copy `github-app.template.yaml` to create `github-app.yaml` and fill in the values.'
		exit 1
	}
	JSON=$(yq github-app.yaml -o=json -I=0)
  kubectl create secret generic github-app --from-literal=credentials="${JSON}"
}
set -x
helmfile sync --wait
kubectl apply -f 01-providers.yaml
kubectl wait --for=condition=Healthy=true provider.pkg.crossplane.io/provider-github
kubectl apply -f 02-providers-config.yaml
kubectl apply -f 03-managed-resources.yaml
kubectl wait --for=condition=Ready=true repositories.repo.github.upbound.io/demo05-repo
kubectl get repositories.repo.github.upbound.io/demo05-repo -o yaml | yq .status.atProvider
: 🎉 GitHub repository demo05-repo is created successfully.
