import crossplane.v1 as xp
import outdent

xp.Composition {
    metadata = {name = "test.suin.jp"}
    spec = {
        compositeTypeRef = {
            apiVersion = "suin.jp/v1"
            kind = "XR1"
        }
        mode = "Pipeline"
        pipeline = [
            {
                step = "pull-xr2"
                functionRef.name = "function-extra-resources"
                input = {
                    apiVersion = "extra-resources.fn.crossplane.io/v1beta1"
                    kind = "Input"
                    spec = {extraResources = [{
                        apiVersion = "suin.jp/v1"
                        kind = "XR2"
                        into = "xr2"
                        type = "Selector"
                        selector = {matchLabels = [{
                            type = "FromCompositeFieldPath"
                            key = "some-label-name"
                            valueFromFieldPath = "spec.xr2"
                        }]}
                    }]}
                }
            }
            {
                step = "kcl"
                functionRef.name = "function-kcl"
                input = {
                    apiVersion = "krm.kcl.dev/v1alpha1"
                    kind = "KCLInput"
                    spec.source = outdent.outdent("""
                    import yaml
                    found = option("params")?.ctx["apiextensions.crossplane.io/extra-resources"]?.xr2
                    print("=== found resources by function-extra-resources ===")
                    print("count: \${len(found)}")
                    print("names: \${[i.metadata.name for i in found]}")
                    print("===")
                    items = []
                    """)
                }
            }
        ]
    }
}
