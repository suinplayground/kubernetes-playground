import manifests
import fluxcd_image_reflector_controller.v1beta2 as fluxcd

# settings
id = "image-repository-ulid"
github_org_name = "suinplayground"
image_repository_name = "some-web-app"
# 
image_repository = fluxcd.ImageRepository {
    metadata.name = id
    metadata.labels = {"appthrust.io/id" = id}
    spec = {
        image = "ghcr.io/${github_org_name}/${image_repository_name}"
        # TODO: make this configurable
        interval = "1m"
        secretRef = {
            # TODO: improve naming
            name = "ghcr-token"
        }
    }
}

objects = [image_repository]
manifests.yaml_stream(objects)
