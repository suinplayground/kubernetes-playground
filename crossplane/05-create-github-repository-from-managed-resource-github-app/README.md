# Create a GitHub repository from a managed resource, but using a GitHub App credentials

This will create a new GitHub repository with name `demo05-repo` in your organization.

## Step 1: Prepare a GitHub organization and GitHub App credentials

- GitHub organization: Create a GitHub organization for this demo.
- GitHub App credentials for your organization with the permissions below:
	- Repository permissions
		- `Administration: Read & write`
	- Organization permissions
		- `Metadata: Read-only`
- GitHub App ID
- GitHub App private key
- GitHub App installation ID

## Step 2: Create a secret for the GitHub personal access token

Copy [./github-app.template.yaml](./github-app.template.yaml) to `github-app.yaml` and fill in the values.

## Step 3: Run demo

```shell
./demo.zsh
```

## Step 4: Clean up

To remove the created demo repository from GitHub, please delete the claim:

```shell
kubectl delete repository demo05-repo
````
