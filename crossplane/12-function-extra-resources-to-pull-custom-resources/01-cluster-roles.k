import manifests
import k8s.api.rbac.v1 as rbac

manifests.yaml_stream([
    rbac.ClusterRole {
        metadata.name = "suin:crossplane:additional"
        rules = [
            {
                apiGroups = ["suin.jp"]
                resources = ["clusterresources"]
                verbs = ["*"]
            }
            {
                apiGroups = ["suin.jp"]
                resources = ["namespacedresources"]
                verbs = ["*"]
            }
        ]
    }
    rbac.ClusterRoleBinding {
        metadata.name = "suin:crossplane:additional"
        roleRef = {
            apiGroup = "rbac.authorization.k8s.io"
            kind = "ClusterRole"
            name = "suin:crossplane:additional"
        }
        subjects = [{
            kind = "ServiceAccount"
            name = "crossplane"
            namespace = "crossplane-system"
        }]
    }
])
