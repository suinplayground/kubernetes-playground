# Crossplane Playground

This repository contains a collection of examples that demonstrate how to use Crossplane to provision and manage cloud services using Kubernetes-style APIs.

## Requirements

- Nix
- Docker

## Setup

Launch a development shell with the following command:

```sh
nix develop
```

Create a new cluster with crossplane installed:

```sh
just setup
```

## Demos

### Demo 1: Create a namespace map from a managed resource

```shell
just setup-kubernetes-provider
kubectl apply -f 01-create-namespace-from-managed-resource/namespace-managed-resource.yaml
```

### Demo 2: Create a namespace map from a managed resource with a custom provider

```shell
just setup-kubernetes-provider
kubectl apply -f 02-create-config-map-from-management-resource/configmap-management-resource.yaml
```

### Demo 3: Create a config map from a claim

```shell
just setup-kubernetes-provider
kubectl apply -f 03-create-config-map-from-claim/myconfigmap-definition.yaml
kubectl apply -f 03-create-config-map-from-claim/myconfigmap-composition.yaml
kubectl apply -f 03-create-config-map-from-claim/myconfigmap-claim.yaml
```

### Demo 4: Create a GitHub repository from a managed resource

Prerequisites:

- GitHub organization
- GitHub personal access token for your organization with the permissions below:
  - Repository permissions
    - `Administration: Read & write`
  - Organization permissions
		- `Metadata: Read-only`

```shell
just setup-github-provider
kubectl apply -f 04-create-github-repository-from-managed-resource/github-repository.yaml
```

This will create a new GitHub repository with name `repo-by-crossplane` in your organization.

## Tear down

Delete the cluster:

```sh
just teardown
```
