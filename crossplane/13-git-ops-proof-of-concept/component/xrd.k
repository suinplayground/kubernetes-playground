import crossplane.v1 as xp
import manifests

xrd = xp.CompositeResourceDefinition {
    metadata = {name = "xcomponents.appthrust.io"}
    spec = {
        names = {
            kind = "XComponent"
            plural = "xcomponents"
        }
        claimNames = {
            kind = "Component"
            plural = "component"
        }
        group = "appthrust.io"
        versions = [{
            name = "v1alpha1"
            served = True
            referenceable = True
            schema.openAPIV3Schema = {}
        }]
    }
}

manifests.yaml_stream([xrd])
