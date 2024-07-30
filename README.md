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

TODO

## Tear down

Delete the cluster:

```sh
just teardown
```
