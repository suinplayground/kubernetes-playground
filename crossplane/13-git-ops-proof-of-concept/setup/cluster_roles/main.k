import k8s.api.rbac.v1 as rbac
import manifests

crossplane_appthrust = rbac.ClusterRole {
    metadata.name = "crossplane:appthrust"
    metadata.annotations = {"appthrust.io/note" = "This setting is required for function-extra-resources."}
    rules = [
        # Permissions that function-extra-resources needs to function properly
        {
            apiGroups = ["image.toolkit.fluxcd.io"]
            resources = ["imagerepositories"]
            verbs = ["list", "get", "watch"]
        }
    ]
}

crossplane_appthrust_binding = rbac.ClusterRoleBinding {
    metadata.name = crossplane_appthrust.metadata.name
    metadata.annotations = {"appthrust.io/note" = "This setting is required for function-extra-resources."}
    roleRef = {
        apiGroup = "rbac.authorization.k8s.io"
        kind = crossplane_appthrust.kind
        name = crossplane_appthrust.metadata.name
    }
    subjects = [{
        kind = "ServiceAccount"
        name = "crossplane"
        namespace = "crossplane-system"
    }]
}

objects = [
    crossplane_appthrust
    crossplane_appthrust_binding
]
manifests.yaml_stream(objects)
