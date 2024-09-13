import json

params = option("params")
oxr = params?.oxr
name: str = oxr?.metadata?.name
version: str = oxr?.spec?.version
image: str = oxr?.spec?.image
imagePullSecret = oxr?.spec?.imagePullSecret
print(json.encode(params, False, 2))
labels = {
    "appthrust.io/project-id" = "project-ulid-here"
    "appthrust.io/application-id" = "application-ulid-here"
    "appthrust.io/component-id" = "component-ulid-here"
    "appthrust.io/component-version" = version
}
deployment = {
    apiVersion = "kubernetes.crossplane.io/v1alpha1"
    kind = "Object"
    metadata = {
        annotations = {
            # TODO: use claim name
            "krm.kcl.dev/composition-resource-name" = name
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "apps/v1"
                kind = "Deployment"
                metadata = {
                    # TODO: claimと同じnamespaceにする
                    namespace = "default"
                }
                spec = {
                    # TODO: prevent hardcoded replicas
                    replicas = 1
                    selector.matchLabels = labels
                    template = {
                        metadata = {
                            # TODO: add common-metadata
                            labels = labels
                        }
                        spec = {
                            imagePullSecrets = [imagePullSecret]
                            containers = [{
                                # TODO: generate a unique name for the container
                                name = "nginx"
                                image = image
                                ports = [{
                                    # TODO
                                    containerPort = 80
                                }]
                            }]
                        }
                    }
                }
            }
        }
    }
}
items = [deployment]
