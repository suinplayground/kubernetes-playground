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
                step = "pull-cluster-resources"
                functionRef.name = "function-extra-resources"
                input = {
                    apiVersion = "extra-resources.fn.crossplane.io/v1beta1"
                    kind = "Input"
                    spec.extraResources = [
                        {
                            apiVersion = "suin.jp/v1"
                            kind = "ClusterResource"
                            into = "cluster_resources"
                            type = "Selector"
                            selector.matchLabels = [{
                                type = "Value"
                                key = "some-label-name"
                                value = "some-label-value"
                            }]
                        }
                        {
                            apiVersion = "suin.jp/v1"
                            kind = "NamespacedResource"
                            into = "namespaced_resources"
                            type = "Selector"
                            selector.matchLabels = [{
                                type = "Value"
                                key = "some-label-name"
                                value = "some-label-value"
                            }]
                        }
                    ]
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
                    extra_resources = option("params")?.ctx["apiextensions.crossplane.io/extra-resources"]
                    print("=== found resources by function-extra-resources ===")
                    print("Found \${len(extra_resources.cluster_resources)} cluster resources and \${len(extra_resources.namespaced_resources)} namespaced resources.")
                    print(yaml.encode({
                        cluster_resources: [r.metadata.name for r in extra_resources.cluster_resources]
                        namespaced_resources: [{ 
                            name = r.metadata.name
                            namespace = r.metadata.namespace
                        } for r in extra_resources.namespaced_resources]
                    }))
                    print("===")
                    items = []
                    """)
                }
            }
        ]
    }
}
