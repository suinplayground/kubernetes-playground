### Proof of Concept: GitOps with Crossplane



```shell
kubectl create secret docker-registry ghcr-token \
  --docker-username=$GITHUB_USERNAME \
  --docker-password=$GITHUB_PAT \
  --docker-server=ghcr.io
```


```shell
./demo.zsh
```