import manifests
import k8s.apiextensions_apiserver.pkg.apis.apiextensions.v1

manifests.yaml_stream([
    v1.CustomResourceDefinition {
        metadata.name = "clusterresources.suin.jp"
        spec = {
            group = "suin.jp"
            scope = "Cluster"
            group = "suin.jp"
            names = {
                kind = "ClusterResource"
                plural = "clusterresources"
                singular = "clusterresource"
            }
            versions = [{
                name = "v1"
                served = True
                storage = True
                schema.openAPIV3Schema = v1.JSONSchemaProps {
                    type = "object"
                    properties = {
                        spec = {type = "object"}
                    }
                }
            }]
        }
    }
    v1.CustomResourceDefinition {
        metadata.name = "namespacedresources.suin.jp"
        spec = {
            group = "suin.jp"
            scope = "Namespaced"
            group = "suin.jp"
            names = {
                kind = "NamespacedResource"
                plural = "namespacedresources"
                singular = "namespacedresource"
            }
            versions = [{
                name = "v1"
                served = True
                storage = True
                schema.openAPIV3Schema = v1.JSONSchemaProps {
                    type = "object"
                    properties = {
                        spec = {type = "object"}
                    }
                }
            }]
        }
    }
])
