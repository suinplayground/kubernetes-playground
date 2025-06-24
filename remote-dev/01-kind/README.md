---
shell: bash
---

# Spinning up a container as an ordinary Pod inside a local "kind" Kubernetes cluster with sharing the host's folder

This example shows how to create a Pod in a local "kind" Kubernetes cluster that shares a folder from the host machine.

## Prerequisites

This project uses [devbox](https://github.com/jetify-com/devbox) to manage its development environment.

Install devbox:

```sh
curl -fsSL https://get.jetpack.io/devbox | bash
```

Start the devbox shell:

```sh
devbox shell
```

If you are using Direnv, it's good option to allow this project so that it automatically loads the devbox environment when you enter the project directory:

```sh
direnv allow
```

## Setup

### Create a kind cluster

To create a local Kubernetes cluster using kind, run the following command:

```sh
kind create cluster --name dev --config kind-config.yaml
```

Verify that the cluster is up and running:

```sh
kubectl cluster-info --context kind-dev
```

## Build your container image

Inside this project folder, run the following command to build the container image:

```sh
docker build -t dev:latest .
```

Make the image visible to the kind cluster:

```sh
kind load docker-image dev:latest --name dev
```

## Run the Pod

Create [dev-pod.yaml](./dev-pod.yaml).

Then run the following command to create a Pod in the kind cluster:

```sh
kubectl apply -f dev-pod.yaml
kubectl wait --for=condition=Ready pod/dev
```

Make sure the Pod is running with mounting the host's current directory:

```bash
touch a-new-file
kubectl exec dev -- ls -la /workspace
rm a-new-file
```

## Launch your web application

To launch your web application, you can use the following command:

```bash
kubectl exec -it dev -- [whatever command you want to run]
```

## Clean up

To delete the kind cluster, run the following command:

```sh
kind delete cluster --name dev
```
