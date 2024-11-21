# Host Helm Chart on GitHub Container Registry

This guide explains how to host a Helm chart on GitHub Container Registry (GHCR).

## Prerequisites

- [Helm](https://helm.sh/docs/intro/install/) installed
- GitHub account with a Classic Personal Access Token (PAT) with `write:packages` scope (Fine-grained permissions are not supported for GHCR)

## Chart Overview

This repository contains a simple Helm chart that creates a hello-world namespace. The chart structure:

```
charts/hello-world/
├── Chart.yaml
├── templates/
│   └── namespace.yaml
```

## Steps to Push Chart to GHCR

### 1. Login to GitHub Container Registry

```bash
helm registry login ghcr.io -u USERNAME
```

Replace `USERNAME` with your GitHub username. When prompted for password, enter your GitHub Classic Personal Access Token (PAT).

### 2. Package the Chart

```bash
helm package charts/hello-world
```

This will create `hello-world-0.1.0.tgz` in the current directory.

### 3. Push to GHCR

```bash
helm push hello-world-0.1.0.tgz oci://ghcr.io/USERNAME
```

Replace `USERNAME` with your GitHub username.

## Using the Chart

To install the chart from GHCR:

```bash
helm install hello-world oci://ghcr.io/USERNAME/hello-world --version 0.1.0
```

Replace `USERNAME` with your GitHub username.

## Cleanup

After testing the chart, you can clean up the resources:

```bash
# Uninstall the Helm release
helm uninstall hello-world

# Delete the created namespace
kubectl delete namespace hello-world

# Remove the local package file
rm hello-world-0.1.0.tgz
```

## Chart Details

- Name: hello-world
- Version: 0.1.0
- Description: A simple Helm chart that creates hello-world namespace
