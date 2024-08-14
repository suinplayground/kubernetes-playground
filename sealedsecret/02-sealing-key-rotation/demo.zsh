#!/usr/bin/env zsh
PS4='%F{blue}⦿%f '
set -euxo pipefail
helmfile sync --wait
: Check that the sealing key is rotated every 3 seconds.
sleep 3
kubectl get secrets -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key
sleep 3
kubectl get secrets -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key
sleep 3
kubectl get secrets -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key
: Stop the sealed-secrets-controller to prevent rotating any more.
helmfile destroy
: To delete all of the sealing keys, run the following command.
: kubectl delete secrets -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key
