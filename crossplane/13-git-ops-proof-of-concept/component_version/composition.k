import crossplane.v1 as xp
import file
import manifests

compositon = xp.Composition {
    metadata = {name = "component-version-to-deployment.appthrust.io"}
    spec = {
        compositeTypeRef = {
            apiVersion = "appthrust.io/v1alpha1"
            kind = "XComponentVersion"
        }
        mode = "Pipeline"
        pipeline = [{
            step = "kcl"
            functionRef.name = "function-kcl"
            input = {
                apiVersion = "krm.kcl.dev/v1alpha1"
                kind = "KCLInput"
                spec.source = file.read("component_version/kcl_functions/main.k")
            }
        }]
    }
}

manifests.yaml_stream([compositon])
