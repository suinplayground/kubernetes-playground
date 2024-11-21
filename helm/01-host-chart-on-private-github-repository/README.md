# Private Helm Chart Repository on GitHub

This repository demonstrates how to host private Helm charts using a private GitHub repository.

## Overview

This repository serves as a private Helm chart repository, showcasing how to:
- Host Helm charts in a private GitHub repository
- Set up authentication for private chart access
- Package and publish charts

## Prerequisites

- GitHub private repository
- GitHub Classic Personal Access Token with `repo` scope
  - Or Fine-grained Personal Access Token with "Contents" Read-Only scope
- Helm CLI installed
- `git` command-line tool

## Chart Details

The repository contains a simple `hello-world` chart that:
- Creates a `hello-world` namespace
- Serves as a minimal example for private chart hosting
- Contains no configurable values

## Setup Instructions

### 1. Create the Chart Package

```bash
cd private-repo
helm package hello-world/
```

### 2. Create the Helm Repository Index

```bash
cd private-repo
helm repo index .
```

### 3. Push the Changes to GitHub

```bash
cd private-repo
git init
git add .
git commit -s -m "Initial commit"
git branch -M main
git remote add origin git@github.com:YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```

### 4. Configure Helm Repository Access

Add the repository to your Helm configuration with authentication:

```bash
helm repo add --username <YOUR_USERNAME> --password <YOUR_GITHUB_TOKEN> private-repo 'https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main'
```

Update the repository:

```bash
helm repo update
```

### 5. Verify Chart Availability

Search for the chart to verify it's available:

```bash
helm search repo private-repo/hello-world
```

Expected output:
```
NAME                        CHART VERSION   APP VERSION   DESCRIPTION
private-repo/hello-world    0.1.0          1.0.0        A simple Helm chart that creates hello-world namespace
```

### 6. Test Chart Installation

You can test the chart installation using the dry-run flag:

```bash
helm install test-hello private-repo/hello-world --dry-run
```

Expected output will show the namespace creation:
```yaml
---
# Source: hello-world/templates/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: hello-world
```

### 7. Install the Chart

To actually install the chart:

```bash
helm install hello-world private-repo/hello-world
```

Expected output:
```
NAME: hello-world
LAST DEPLOYED: Thu Nov 21 14:45:40 2024
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

## Repository Structure

```
.
├── README.md
├── index.yaml              # Helm repository index file
├── hello-world-0.1.0.tgz   # Packaged Helm chart
└── hello-world/           # Helm chart source directory
    ├── Chart.yaml         # Chart metadata
    └── templates/         # Chart templates
        └── namespace.yaml
```

## Notes

- Keep your GitHub Personal Access Token secure
- Update the repository URL according to your GitHub username and repository name
- The chart version can be found in `hello-world/Chart.yaml`
- Always verify chart availability using `helm search repo` before installation
- Use `--dry-run` flag to preview chart installation
