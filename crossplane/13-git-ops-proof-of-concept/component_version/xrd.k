import crossplane.v1 as xp
import k8s.apiextensions_apiserver.pkg.apis.apiextensions.v1
import manifests

xrd = xp.CompositeResourceDefinition {
    metadata = {name = "xcomponentversions.appthrust.io"}
    spec = {
        names = {
            kind = "XComponentVersion"
            plural = "xcomponentversions"
        }
        claimNames = {
            kind = "ComponentVersion"
            plural = "componentversions"
        }
        group = "appthrust.io"
        versions = [{
            name = "v1alpha1"
            served = True
            referenceable = True
            additionalPrinterColumns = [
                {
                    name = "Version"
                    description = "The version of the component"
                    jsonPath = ".spec.version"
                    type = "string"
                }
                {
                    name = "Image"
                    description = "The image of the component"
                    jsonPath = ".spec.image"
                    type = "string"
                }
            ]
            schema.openAPIV3Schema = v1.JSONSchemaProps {
                type = "object"
                properties = {
                    spec = {
                        type = "object"
                        properties = {
                            version = {type = "string"}
                            image = {type = "string"}
                            imagePullSecret = {
                                type = "object"
                                properties = {
                                    name = {type = "string"}
                                }
                                required = ["name"]
                            }
                        }
                        required = [
                            "version"
                            "image"
                        ]
                    }
                }
            }
        }]
    }
}

manifests.yaml_stream([xrd])
