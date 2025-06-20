# Using mirror.gcr.io as a Docker Hub Mirror for Cluster API Management and Workload Clusters

## Introduction

When working with Kubernetes clusters, especially in CI/CD pipelines or during rapid prototyping, you may encounter Docker Hub's rate limits. These limits can severely disrupt your workflow, causing failed image pulls and unnecessary delays. To avoid this, you can configure your clusters to use [mirror.gcr.io](https://cloud.google.com/container-registry/docs/pulling-cached-images) as a pull-through cache for Docker Hub images. This guide demonstrates how to set up both your **management** and **workload** clusters (using [Cluster API](https://cluster-api.sigs.k8s.io/)) to use mirror.gcr.io as a registry mirror, ensuring smooth, rate-limit-free image pulls.

---

## Why Use mirror.gcr.io?

- **Bypass Docker Hub Rate Limits:** mirror.gcr.io caches Docker Hub images, so your clusters pull from Google's mirror instead of Docker Hub directly.
- **Faster Image Pulls:** Cached images are often served faster from Google's infrastructure.
- **Reliability:** Avoid disruptions due to Docker Hub outages or throttling.

---

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed
- [kind](https://kind.sigs.k8s.io/) (Kubernetes IN Docker) installed
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed
- [clusterctl](https://cluster-api.sigs.k8s.io/user/quick-start.html#install-clusterctl) installed
- [yq](https://github.com/mikefarah/yq) installed (for YAML processing)

---

## Step 1: Prepare the Registry Mirror Configuration

Create a directory structure and a configuration file for containerd to use mirror.gcr.io as a registry mirror for Docker Hub.

```bash
mkdir -p certs.d/docker.io
cat > certs.d/docker.io/hosts.toml <<EOF
server = "https://registry-1.docker.io"

[host."https://mirror.gcr.io"]
  capabilities = ["pull"]

[host."https://registry-1.docker.io"]
  capabilities = ["pull", "resolve"]
EOF
```

This configuration separates pull and resolve operations to prevent stale cache issues. The mirror.gcr.io handles image pulls (leveraging cached images), while registry-1.docker.io handles tag resolution and metadata queries, ensuring you always get the latest tag information without cache staleness.

---

## Step 2: Configure kind Cluster to Use the Mirror

Create a `kind-cluster.yaml` file with the following content. This configures kind's internal containerd to use the mirror and enables debug logging for troubleshooting.

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  ipFamily: dual
nodes:
  - role: control-plane
    image: kindest/node:v1.33.1
    extraMounts:
      # Mounts the Docker socket so that the Cluster API Docker provider (CAPD) can access the host Docker.
      - hostPath: /var/run/docker.sock
        containerPath: /var/run/docker.sock
      # Mounts the custom registry mirror configuration into the containerd config directory inside the node.
      - hostPath: ./certs.d
        containerPath: /etc/containerd/certs.d
# Tells containerd to pull images for docker.io and registry.k8s.io from Google's mirror.gcr.io first.
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry]
      config_path = "/etc/containerd/certs.d"
    # Enable debug mode to check if mirror.gcr.io is used.
    # The log can be seen by running `docker exec -it <cluster-name>-control-plane bash -c 'journalctl -u containerd -f & crictl pull nginx'`
    [debug]
      level = "debug"
```

**Explanation of Each Part:**

- `kind: Cluster` and `apiVersion`: Define this as a kind cluster configuration.
- `networking.ipFamily: dual`: Enables both IPv4 and IPv6 networking.
- `nodes`: Defines the nodes in the cluster. Here, we use a single control-plane node.
- `image`: Specifies the node image version (should match your Kubernetes version needs).
- `extraMounts`:
  - Mounts the Docker socket for CAPD (Cluster API Docker provider) to manage Docker containers.
  - Mounts the `certs.d` directory (with your mirror config) into the node, so containerd can find and use it.
- `containerdConfigPatches`:
  - Directs containerd to use the custom registry config path for registry settings.
  - Enables debug logging for easier troubleshooting of image pulls and mirror usage.

---

## Step 3: Create the Management Cluster

```bash
kind create cluster --name management --config kind-cluster.yaml
```

This mounts your custom registry config and enables debug logging. You can verify the mirror is used by pulling an image and checking the logs:

```bash
docker exec -it management-control-plane bash -c 'crictl pull hello-world && journalctl -u containerd' | grep fetch | grep mirror.gcr.io
```

You should see log lines indicating that images are being fetched from `mirror.gcr.io`.

---

## Step 4: Initialize Cluster API on the Management Cluster

```bash
clusterctl init --infrastructure docker
```

This installs Cluster API components on your management cluster.

---

## Step 5: Patch Workload Cluster Templates for the Mirror

When you create a workload cluster with Cluster API, you need to ensure that the nodes in the workload cluster are also configured to use the registry mirror. This is done by injecting pre-boot commands into the cluster templates.

Create a `patch.yaml` file with the following content:

```yaml
- name: containerd-customization
  description: "Customize containerd with mirror, debug, and restart"
  definitions:
    - selector:
        apiVersion: controlplane.cluster.x-k8s.io/v1beta1
        kind: KubeadmControlPlaneTemplate
        matchResources:
          controlPlane: true
      jsonPatches:
        - op: add
          path: /spec/template/spec/kubeadmConfigSpec/preKubeadmCommands
          value:
            - |
              # The one script to rule them all
              set -e

              # 1. Create hosts.toml for mirror
              mkdir -p /etc/containerd/certs.d/docker.io
              cat <<EOF > /etc/containerd/certs.d/docker.io/hosts.toml
              server = "https://registry-1.docker.io"

              [host."https://mirror.gcr.io"]
                capabilities = ["pull"]

              [host."https://registry-1.docker.io"]
                capabilities = ["pull", "resolve"]
              EOF

              # 2. Add debug config idempotently
              if ! grep -q '\[debug\]' /etc/containerd/config.toml; then
                sed -i '/version = 2/a [debug]\n  level = "debug"' /etc/containerd/config.toml
              fi

              # 3. Add registry config_path idempotently (The final piece!)
              if ! grep -q 'config_path = "/etc/containerd/certs.d"' /etc/containerd/config.toml; then
                printf '\n[plugins."io.containerd.grpc.v1.cri".registry]\n  config_path = "/etc/containerd/certs.d"\n' >> /etc/containerd/config.toml
              fi

              # 4. Restart containerd to apply all changes
              systemctl restart containerd
    - selector:
        apiVersion: bootstrap.cluster.x-k8s.io/v1beta1
        kind: KubeadmConfigTemplate
        matchResources:
          machineDeploymentClass:
            names: ["default-worker"]
      jsonPatches:
        - op: add
          path: /spec/template/spec/preKubeadmCommands
          value:
            - |
              # The one script to rule them all
              set -e

              # 1. Create hosts.toml for mirror
              mkdir -p /etc/containerd/certs.d/docker.io
              cat <<EOF > /etc/containerd/certs.d/docker.io/hosts.toml
              server = "https://registry-1.docker.io"

              [host."https://mirror.gcr.io"]
                capabilities = ["pull"]

              [host."https://registry-1.docker.io"]
                capabilities = ["pull", "resolve"]
              EOF

              # 2. Add debug config idempotently
              if ! grep -q '\[debug\]' /etc/containerd/config.toml; then
                sed -i '/version = 2/a [debug]\n  level = "debug"' /etc/containerd/config.toml
              fi

              # 3. Add registry config_path idempotently (The final piece!)
              if ! grep -q 'config_path = "/etc/containerd/certs.d"' /etc/containerd/config.toml; then
                printf '\n[plugins."io.containerd.grpc.v1.cri".registry]\n  config_path = "/etc/containerd/certs.d"\n' >> /etc/containerd/config.toml
              fi

              # 4. Restart containerd to apply all changes
              systemctl restart containerd
```

**Explanation of Each Part:**

- `name` and `description`: Metadata for the patch, describing its purpose.
- `definitions`: List of patch definitions for different node types.
- Each `selector` targets a specific Cluster API template kind (control plane or worker nodes).
- `jsonPatches`: List of JSON patch operations to inject commands into the node boot process.
- The shell script in `preKubeadmCommands` does:
  1. **Create the mirror config**: Writes the `hosts.toml` file for containerd to use mirror.gcr.io.
  2. **Enable debug logging**: Adds a debug section to containerd's config if not already present.
  3. **Set registry config path**: Ensures containerd knows where to find the mirror config.
  4. **Restart containerd**: Applies all changes by restarting the containerd service.
- This patch is applied to both control plane and worker nodes, ensuring all nodes use the mirror.

---

## Step 6: Generate and Apply the Workload Cluster Manifest

In this step, you will generate the manifest for your workload cluster, patch it to include the containerd customization, and then apply it to your management cluster. Here's what each part does and why:

- **Generate the cluster manifest**: `clusterctl generate cluster workload ...` creates a YAML manifest describing your new workload cluster, including its topology, machine templates, and configuration.
- **Process with yq**: The first `yq` command is used to parse and format the YAML for further manipulation.
- **Save the original**: `tee workload.original.yaml` saves the unpatched manifest for reference or debugging.
- **Patch the ClusterClass**: The second `yq` command appends the contents of your `patch.yaml` to the `spec.patches` field of the `ClusterClass` object in the manifest. This ensures that when the cluster is created, the preKubeadmCommands (which configure the registry mirror) are injected into the node bootstrapping process.
- **Save the patched manifest**: `tee workload.patched.yaml` saves the patched manifest so you can inspect exactly what will be applied.
- **Apply to the cluster**: `kubectl apply -f -` sends the patched manifest to the management cluster, which will then create the workload cluster according to your specifications.

```bash
clusterctl generate cluster workload \
  --flavor development \
  --kubernetes-version v1.33.1 \
  --control-plane-machine-count=1 \
  --worker-machine-count=1 \
  | yq \
  | tee workload.original.yaml \
  | yq 'select(.kind == "ClusterClass").spec.patches += load("patch.yaml")' \
  | tee workload.patched.yaml \
  | kubectl apply -f -
```

**What Happens:**

- The management cluster receives the manifest and starts creating the workload cluster.
- As each node in the workload cluster boots, it runs the preKubeadmCommands injected by your patch, configuring containerd to use mirror.gcr.io.
- All subsequent image pulls on these nodes will use the mirror, bypassing Docker Hub rate limits.
- You can inspect both the original and patched manifests to understand exactly what is being deployed.

---

## Step 7: Verify the Mirror is Used in the Workload Cluster

To check if the workload cluster nodes are using the mirror, run:

```bash
for container in $(kubectl --context=kind-management get machines -o custom-columns=NAME:.metadata.name --no-headers); do
  echo
  echo === $container ===
  docker exec -it $container bash -c 'crictl pull hello-world && journalctl -u containerd' | grep fetch | grep mirror.gcr.io
done
```

You should see log lines for each node showing image pulls from `mirror.gcr.io`.

---

## Step 8: (Optional) Install a CNI Plugin

For example, to install Calico:

```bash
kubectl --context=kind-workload apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
```

---

## Conclusion

By following these steps, both your management and workload clusters will use mirror.gcr.io as a pull-through cache for Docker Hub images. This setup helps you avoid Docker Hub rate limits and ensures reliable, fast image pulls for all your Kubernetes workloads.

---

## References

- [Google Container Registry Mirror](https://cloud.google.com/container-registry/docs/pulling-cached-images)
- [kind Registry Configuration](https://kind.sigs.k8s.io/docs/user/local-registry/)
- [Cluster API Book](https://cluster-api.sigs.k8s.io/)
