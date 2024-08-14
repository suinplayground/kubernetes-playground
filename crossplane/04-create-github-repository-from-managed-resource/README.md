# Create a GitHub repository from a managed resource

This will create a new GitHub repository with name `demo04-repo` in your organization.

## Step 1: Create a GitHub organization and personal access token

- GitHub organization: Create a GitHub organization for this demo.
- GitHub personal access token for your organization with the permissions below:
	- Repository permissions
		- `Administration: Read & write`
	- Organization permissions
		- `Metadata: Read-only`

## Step 2: Create a secret for the GitHub personal access token

Copy [./personal.template.yaml](./personal.template.yaml) to `personal.yaml` and fill in the values.

## Step 3: Run demo

```shell
./demo.zsh
```

## Step 4: Clean up

To remove the created demo repository from GitHub, please delete the claim:

```shell
kubectl delete repository demo04-repo
````
