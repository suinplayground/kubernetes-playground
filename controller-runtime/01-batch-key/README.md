# pseudo-cluster-scope-key

A Kubernetes controller demonstrating the **BatchKey** pattern for efficient resource grouping and processing.

## Description

This project demonstrates an advanced controller pattern that extends controller-runtime's standard exclusion control (namespace+name) to arbitrary scope exclusion control using the **BatchKey** pattern.

**Standard Control**: Each Job is processed individually (spec.next dependencies ignored)
```
Job1 (queue: "queue-a", next: "job2") → Individual processing
Job2 (queue: "queue-a", next: "job3") → Individual processing  
Job3 (queue: "queue-b", next: "")     → Individual processing
```

**BatchKey Control**: Jobs are grouped by queue and processed according to spec.next dependencies
```
Job1, Job2 (queue: "queue-a") → Sequential: job1 → job2 (spec.next order)
Job3, Job4 (queue: "queue-b") → Sequential: job3 → job4 (parallel queue)
```

This approach is particularly effective for implementing job queue systems with dependency management, workflow orchestration, and scenarios requiring coordinated processing with strict ordering guarantees.

## Features

- **Queue Processing**: Groups Jobs by `spec.queue` field value for dependency-aware execution within queues
- **Dependency Management**: Implements `spec.next` field for explicit Job ordering and dependency chains
- **Parallel Queue Execution**: Different queue types are processed in parallel (up to 8 concurrent reconciles)
- **Field Indexing**: Uses controller-runtime field indexers for efficient Job querying
- **Prefix Pattern**: Implements prefixed keys (`spec.queue:value`) for better maintainability and debugging
- **Strict Ordering**: Ensures Jobs within the same queue are processed according to spec.next dependencies

## Documentation

📚 **[BatchKey 実装ガイド](./docs/batch-key.md)** - Complete implementation guide (Japanese)

Key topics covered:
- Implementation patterns and architecture
- Step-by-step implementation guide
- Benefits and best practices
- Extension examples and naming conventions

## Getting Started

### Prerequisites
- go version v1.23.0+
- docker version 17.03+.
- kubectl version v1.11.3+.
- Access to a Kubernetes v1.11.3+ cluster.

### To Deploy on the cluster
**Build and push your image to the location specified by `IMG`:**

```sh
make docker-build docker-push IMG=<some-registry>/pseudo-cluster-scope-key:tag
```

**NOTE:** This image ought to be published in the personal registry you specified.
And it is required to have access to pull the image from the working environment.
Make sure you have the proper permission to the registry if the above commands don’t work.

**Install the CRDs into the cluster:**

```sh
make install
```

**Deploy the Manager to the cluster with the image specified by `IMG`:**

```sh
make deploy IMG=<some-registry>/pseudo-cluster-scope-key:tag
```

> **NOTE**: If you encounter RBAC errors, you may need to grant yourself cluster-admin
privileges or be logged in as admin.

**Create instances of your solution**
You can apply the samples (examples) from the config/sample:

```sh
kubectl apply -k config/samples/
```

>**NOTE**: Ensure that the samples has default values to test it out.

### To Uninstall
**Delete the instances (CRs) from the cluster:**

```sh
kubectl delete -k config/samples/
```

**Delete the APIs(CRDs) from the cluster:**

```sh
make uninstall
```

**UnDeploy the controller from the cluster:**

```sh
make undeploy
```

## Project Distribution

Following the options to release and provide this solution to the users.

### By providing a bundle with all YAML files

1. Build the installer for the image built and published in the registry:

```sh
make build-installer IMG=<some-registry>/pseudo-cluster-scope-key:tag
```

**NOTE:** The makefile target mentioned above generates an 'install.yaml'
file in the dist directory. This file contains all the resources built
with Kustomize, which are necessary to install this project without its
dependencies.

2. Using the installer

Users can just run 'kubectl apply -f <URL for YAML BUNDLE>' to install
the project, i.e.:

```sh
kubectl apply -f https://raw.githubusercontent.com/<org>/pseudo-cluster-scope-key/<tag or branch>/dist/install.yaml
```

### By providing a Helm Chart

1. Build the chart using the optional helm plugin

```sh
kubebuilder edit --plugins=helm/v1-alpha
```

2. See that a chart was generated under 'dist/chart', and users
can obtain this solution from there.

**NOTE:** If you change the project, you need to update the Helm Chart
using the same command above to sync the latest changes. Furthermore,
if you create webhooks, you need to use the above command with
the '--force' flag and manually ensure that any custom configuration
previously added to 'dist/chart/values.yaml' or 'dist/chart/manager/manager.yaml'
is manually re-applied afterwards.

## Contributing
// TODO(user): Add detailed information on how you would like others to contribute to this project

**NOTE:** Run `make help` for more information on all potential `make` targets

More information can be found via the [Kubebuilder Documentation](https://book.kubebuilder.io/introduction.html)

## License

Copyright 2025 suin.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

