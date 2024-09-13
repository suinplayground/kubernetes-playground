import k8s.api.core.v1 as core
import k8s.api.rbac.v1 as rbac
import manifests

name = "provider-kubernetes"
service_account = core.ServiceAccount {
    metadata.name = name
    metadata.namespace = "crossplane-system"
}

role = rbac.ClusterRole {
    metadata.name = "appthrust:deployments:admin"
    rules = [{
        apiGroups = ["apps"]
        resources = ["deployments"]
        verbs = ["*"]
    }]
}

role_binding = rbac.ClusterRoleBinding {
    metadata.name = service_account.metadata.name
    roleRef = {
        apiGroup = "rbac.authorization.k8s.io"
        kind = role.kind
        name = role.metadata.name
    }
    subjects = [{
        kind: service_account.kind
        name: service_account.metadata.name
        namespace: service_account.metadata.namespace
    }]
}

provider = {
    apiVersion = "pkg.crossplane.io/v1"
    kind = "Provider"
    metadata.name = name
    spec = {
        package = "xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.14.1"
        runtimeConfigRef = {
            apiVersion: deployment_runtime_config.apiVersion
            kind: deployment_runtime_config.kind
            name: deployment_runtime_config.metadata.name
        }
    }
}
deployment_runtime_config = {
    apiVersion = "pkg.crossplane.io/v1beta1"
    kind = "DeploymentRuntimeConfig"
    metadata.name = name
    spec = {
        deploymentTemplate = {
            spec = {
                selector = {}
                template = {
                    spec = {
                        serviceAccountName = service_account.metadata.name
                        containers = [{
                            name = "package-runtime"
                            args = ["--debug"]
                        }]
                    }
                }
            }
        }
    }
}
objects = [
    service_account
    role
    role_binding
    provider
    deployment_runtime_config
]
manifests.yaml_stream(objects)
