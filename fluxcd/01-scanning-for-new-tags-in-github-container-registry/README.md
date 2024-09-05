# FluxCD: Scanning for New Tags in GitHub Container Registry

Welcome to this comprehensive guide on integrating FluxCD with GitHub Container Registry (GHCR). In this demonstration, we'll explore how FluxCD's `ImageRepository` resource synchronizes tags when images are pushed to GHCR.

Let's dive into the process, which consists of five key steps:

1. Pushing Docker images to GHCR
2. Setting up FluxCD
3. Configuring image tag retrieval from GHCR
4. Pushing new tags and verifying scan results
5. Cleaning up resources

Now, let's walk through each step in detail.

## Pushing Docker Images to GitHub Container Registry

### Creating a GitHub Personal Access Token (PAT)

First things first, we need to create a GitHub Personal Access Token. Head over to:
https://github.com/settings/tokens/new

Select "personal access token (classic)" as the token type. At the time of writing, the Package Read scope isn't available for fine-grained PATs, so we'll stick with the classic version. Label it "package-write-token" and select the `write:packages` scope.

### Logging into GitHub Container Registry

With your shiny new PAT in hand, let's log into GHCR. Run the following command, replacing `$GITHUB_PAT` with your actual PAT and `$GITHUB_USERNAME` with your GitHub username:

```shell
echo -n $GITHUB_PAT | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin
```

### Building Your Docker Image

Time to build your Docker image. Execute this command, substituting `$GITHUB_ORG_NAME` with your GitHub organization name:

```shell
docker build -t ghcr.io/$GITHUB_ORG_NAME/some-web-app:1.0.0 .
```

### Pushing the Image

Now, let's push that freshly built image to GHCR:

```shell
docker push ghcr.io/$GITHUB_ORG_NAME/some-web-app:1.0.0
```

### Verifying on GitHub

To ensure everything went smoothly, navigate to your GitHub organization page and click on the "Packages" tab. You should see your newly pushed package listed there. Keep in mind that packages are set to private by default on their first push.

## Setting Up FluxCD

Let's get FluxCD up and running in your Kubernetes cluster. It's as simple as running:

```shell
helmfile sync
```

## Configuring Image Tag Retrieval from GitHub Container Registry

### Creating a Secret for GitHub Container Registry

To allow FluxCD to pull images from GHCR, we need to create a Kubernetes Secret.

First, generate another GitHub Personal Access Token:
https://github.com/settings/tokens/new

This time, choose "personal access token (classic)", label it "package-read-token", and select the `read:packages` scope. Remember, we're still avoiding fine-grained PATs for now.

Use this token to create the Secret with the following command. Make sure to name it `github-registry-pull-secret`:

```shell
kubectl create secret docker-registry github-registry-pull-secret \
  --docker-username=$GITHUB_USERNAME \
  --docker-password=$GITHUB_PAT \
  --docker-server=ghcr.io
```

### Creating FluxCD's `ImageRepository` Resource

Open the `01-image-repositories.yaml` file and update the `spec.image` value from `ghcr.io/$GITHUB_ORG_NAME/some-web-app` to your actual GitHub organization name.

After making the change, create the `ImageRepository` resource:

```shell
kubectl apply -f 01-image-repositories.yaml
```

Give FluxCD a moment to scan the registry. Soon, you'll see a list of tags in `status.lastScanResult`. Check it out with:

```shell
kubectl get imagerepository some-web-app -o yaml | yq .status.lastScanResult
```

You should see something like this:

```yaml
latestTags:
  - 1.0.0
scanTime: "2024-09-05T07:38:33Z"
tagCount: 1
```

## Pushing New Tags and Verifying Scan Results

Let's spice things up by pushing a new tag and seeing how the `ImageRepository` resource reacts.

Push version 2.0.0 with these commands:

```shell
docker build -t ghcr.io/$GITHUB_ORG_NAME/some-web-app:2.0.0 .
docker push ghcr.io/$GITHUB_ORG_NAME/some-web-app:2.0.0
```

After a short wait, the new tag should appear in `status.lastScanResult`. Let's check:

```shell
sleep 300 # Wait for 5 minutes
kubectl get imagerepository some-web-app -o yaml | yq .status.lastScanResult
```

We're waiting for 5 minutes to align with the scan interval specified in `01-image-repositories.yaml`. The result should look like this:

```yaml
latestTags:
  - 2.0.0
  - 1.0.0
scanTime: "2024-09-05T07:43:34Z"
tagCount: 2
```

## Cleaning Up

Once you're done with the demo, it's time to tidy up. Delete the `ImageRepository` resource to stop the periodic fetching of image tag information from GHCR:

```shell
kubectl delete imagerepository some-web-app
```

And there you have it! You've successfully completed the FluxCD and GitHub Container Registry integration demo. Well done!
