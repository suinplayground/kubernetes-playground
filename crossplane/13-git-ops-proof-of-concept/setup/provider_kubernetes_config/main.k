import manifests

provider_config = {
    apiVersion = "kubernetes.crossplane.io/v1alpha1"
    kind = "ProviderConfig"
    metadata.name = "default"
    spec = {
        credentials = {source = "InjectedIdentity"}
    }
}
objects = [provider_config]
manifests.yaml_stream(objects)
