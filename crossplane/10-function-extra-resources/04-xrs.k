import manifests

manifests.yaml_stream([
    {
        apiVersion = "suin.jp/v1"
        kind = "XR1"
        metadata.name = "object1"
        spec = {}
    }
    {
        apiVersion = "suin.jp/v1"
        kind = "XR2"
        metadata.name = "object2"
        metadata.labels = {"some-label-name" = "some-label-value"}
        spec = {}
    }
    {
        apiVersion = "suin.jp/v1"
        kind = "XR2"
        metadata.name = "object3"
        metadata.labels = {"some-label-name" = "some-label-value"}
        spec = {}
    }
])
