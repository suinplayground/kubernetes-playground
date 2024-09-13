import manifests
import ..connect_image_repository

# Inputs
version = "1.0.0"
ulid = "01j7mam136xhj4f3xydx3hj7we"
#
component_version = {
    apiVersion = "appthrust.io/v1alpha1"
    kind = "ComponentVersion"
    metadata.name = "component-version-${ulid}"
    spec = {
        version = version
        image = "${connect_image_repository.image_repository.spec.image}:${version}"
        imagePullSecret.name = "ghcr-token"
    }
}
objects = [component_version]
manifests.yaml_stream(objects)
