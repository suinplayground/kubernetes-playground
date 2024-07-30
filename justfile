setup:
	k3d cluster create --config cluster.yaml
	helmfile sync

teardown:
	k3d cluster delete --config cluster.yaml
