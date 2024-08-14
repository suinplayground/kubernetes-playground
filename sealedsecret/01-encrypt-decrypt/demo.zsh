#!/usr/bin/env zsh
PS4='%F{blue}⦿%f '
set -euxo pipefail
helmfile sync --wait
: Use kubeseal to convert this Secret to SealedSecret.
kubeseal --format yaml < 01-secret.yaml > 02-mysealedsecret.yaml
: Deploy the generated SealedSecret to the cluster.
kubectl apply -f 02-mysealedsecret.yaml
: Check the deployed Secret
kubectl get secrets
: You should see a Secret named mysecret.
kubectl-view-secret mysecret -a
