import manifests

manifests.yaml_stream([
    {
        apiVersion = "suin.jp/v1"
        kind = "ClusterResource"
        metadata.name = "cluster-resource-1"
        metadata.labels = {"some-label-name" = "some-label-value"}
        spec = {}
    }
    {
        apiVersion = "suin.jp/v1"
        kind = "NamespacedResource"
        metadata.name = "namespaced-resource-1"
        metadata.namespace = "default"
        metadata.labels = {"some-label-name" = "some-label-value"}
        spec = {}
    }
    {
        apiVersion = "suin.jp/v1"
        kind = "NamespacedResource"
        metadata.name = "namespaced-resource-1"
        metadata.namespace = "my-namespace"
        metadata.labels = {"some-label-name" = "some-label-value"}
        spec = {}
    }
])
