import k8s.api.core.v1 as core

core.Pod {
    metadata = {
        name = "echo"
    }
    spec = {
        containers = [
            {
                name = "echo"
                image = "gcr.io/k8s-staging-gateway-api/echo-basic"
            }
        ]
    }
}
