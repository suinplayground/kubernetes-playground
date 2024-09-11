import manifests
import crossplane.v1 as xp
import k8s.apiextensions_apiserver.pkg.apis.apiextensions.v1

manifests.yaml_stream([xp.CompositeResourceDefinition {
    metadata = {name = "xr1.suin.jp"}
    spec = {
        names = {
            kind = "XR1"
            plural = "xr1"
        }
        group = "suin.jp"
        versions = [{
            name = "v1"
            served = True
            referenceable = True
            schema.openAPIV3Schema = v1.JSONSchemaProps {}
        }]
    }
}])
