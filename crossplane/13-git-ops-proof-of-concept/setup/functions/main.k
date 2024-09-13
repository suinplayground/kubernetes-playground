import manifests

kcl = {
    apiVersion = "pkg.crossplane.io/v1beta1"
    kind = "Function"
    metadata.name = "function-kcl"
    spec.package = "xpkg.upbound.io/crossplane-contrib/function-kcl:v0.9.0"
}
auto_ready = {
    apiVersion = "pkg.crossplane.io/v1beta1"
    kind = "Function"
    metadata.name = "function-auto-ready"
    spec.package = "xpkg.upbound.io/crossplane-contrib/function-auto-ready:v0.2.1"
}
extra_resources = {
    apiVersion = "pkg.crossplane.io/v1beta1"
    kind = "Function"
    metadata.name = "function-extra-resources"
    spec.package = "xpkg.upbound.io/crossplane-contrib/function-extra-resources:v0.0.3"
}
objects = [kcl, auto_ready, extra_resources]
manifests.yaml_stream(objects)
