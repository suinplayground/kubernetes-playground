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
just install-kubernetes-provider
just setup-kubernetes-provider-config
kubectl apply -f 01-create-namespace-from-managed-resource/namespace-managed-resource.yaml
```

### Demo 2: Create a namespace map from a managed resource with a custom provider

```shell
just install-kubernetes-provider
just setup-kubernetes-provider-config
kubectl apply -f 02-create-config-map-from-management-resource/configmap-management-resource.yaml
```

### Demo 3: Create a config map from a claim

```shell
just install-kubernetes-provider
just setup-kubernetes-provider-config
kubectl apply -f 03-create-config-map-from-claim/myconfigmap-definition.yaml
kubectl apply -f 03-create-config-map-from-claim/myconfigmap-composition.yaml
kubectl apply -f 03-create-config-map-from-claim/myconfigmap-claim.yaml
```

See also "Demo 6: Create a config map from a composite resource" for an alternative way to create a config map.

### Demo 4: Create a GitHub repository from a managed resource

Prerequisites:

- GitHub organization
- GitHub personal access token for your organization with the permissions below:
  - Repository permissions
    - `Administration: Read & write`
  - Organization permissions
		- `Metadata: Read-only`

```shell
just install-github-provider
just setup-for-github-personal
kubectl apply -f 04-create-github-repository-from-managed-resource/github-repository.yaml
```

This will create a new GitHub repository with name `test-repo-1` in your organization.

To remove the created demo repository from GitHub, please delete the claim:

```shell
kubectl delete repository repo1
````

### Demo 5: Create a GitHub repository from a managed resource, but using a GitHub App credentials

Prerequisites:

- GitHub organization
- GitHub App credentials for your organization with the permissions below:
	- Repository permissions
		- `Administration: Read & write`
	- Organization permissions
		- `Metadata: Read-only`
- GitHub App ID
- GitHub App private key
- GitHub App installation ID

```shell
just install-github-provider
just setup-for-github-app
kubectl apply -f 05-create-github-repository-from-managed-resource-github-app/github-repository.yaml
```

This will create a new GitHub repository with name `test-repo-2` in your organization.

To remove the created demo repository from GitHub, please delete the claim:

```shell
kubectl delete repository repo2
````

### Demo 6: Create a config map from a composite resource

This demo creates a config map by directly creating a composite resource without going through a claim.

```shell
just install-kubernetes-provider
just setup-kubernetes-provider-config
kubectl apply -f 03-create-config-map-from-claim/myconfigmap-definition.yaml
kubectl apply -f 03-create-config-map-from-claim/myconfigmap-composition.yaml
kubectl apply -f 06-create-config-map-from-composite-resource/xconfigmap-composite-resource.yaml
```

## Tear down

Delete the cluster:

```sh
just teardown
```
