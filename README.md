# Kubernetes Playground

This repository contains a collection of examples that demonstrate how to use Crossplane to provision and manage cloud services using Kubernetes-style APIs.

## Requirements

- Nix
- Docker

## Getting started

Launch a development shell with the following command:

```sh
nix develop
```

Create a new cluster with crossplane installed:

```sh
just setup
```

## Crossplane

The [crossplane](crossplane) directory contains a collection of examples that demonstrate how to use Crossplane to provision and manage cloud services.

1. [Create a namespace map from a managed resource](crossplane/01-create-namespace-from-managed-resource/README.md)
2. [Create a namespace map from a managed resource with a custom provider](crossplane/02-create-config-map-from-management-resource/README.md)
3. [Create a config map from a claim](crossplane/03-create-config-map-from-claim/README.md)
4. [Create a GitHub repository from a managed resource](crossplane/04-create-github-repository-from-managed-resource/README.md)
5. [Create a GitHub repository from a managed resource, but using a GitHub App credentials](crossplane/05-create-github-repository-from-managed-resource-github-app/README.md)
6. [Create a config map from a composite resource](crossplane/06-create-config-map-from-composite-resource/README.md)
7. [Create a config and a secret map with pipeline mode](crossplane/07-create-config-map-with-pipeline-mode/README.md)
8. [Create a config map with KCL](crossplane/08-create-config-with-kcl/README.md)
9. [Create two config maps with KCL (one depends on the other)](crossplane/09-create-config-with-kcl-dependency/README.md)
10. [`function-extra-resources` basic example](crossplane/10-function-extra-resources/README.md)
11. [`function-extra-resources` with `FromCompositeFieldPath`](crossplane/11-function-extra-resources-type-from-composite-field-path/README.md)
12. [`function-extra-resources` to fetch custom resources that are not XRs](crossplane/12-function-extra-resources-to-pull-custom-resources/README.md)

## SealedSecret

SealedSecret is a Kubernetes Custom Resource Definition that allows you to store encrypted secrets in Git.

1. [Encrypt a secret and decrypt sealed secret](sealedsecret/01-encrypt-decrypt/README.md)
2. [What happens when sealing key rotation occurs?](sealedsecret/02-sealing-key-rotation/README.md)

## FluxCD

1. [Scanning for New Tags in GitHub Container Registry](fluxcd/01-scanning-for-new-tags-in-github-container-registry/README.md)

## Tear down

Delete the cluster:

```sh
just teardown
```
