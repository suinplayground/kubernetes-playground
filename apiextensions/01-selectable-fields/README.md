# CRD Selectable Fields

This documentation demonstrates how to use field selectors with Custom Resource Definitions (CRDs) in Kubernetes. Field selectors allow you to query custom resources based on the value of specific fields, similar to how you can query built-in resources like Pods. This feature is available in Kubernetes v1.31+ and requires the `CustomResourceFieldSelectors` feature gate to be enabled.

## Getting Started

This project uses [devbox](https://github.com/jetify-com/devbox) to manage its development environment.

Install devbox:

```sh
curl -fsSL https://get.jetpack.io/devbox | bash
```

Start the devbox shell:
```sh 
devbox shell
```


## Create a cluster

We'll create a Kind cluster with Kubernetes v1.31+ to ensure the `CustomResourceFieldSelectors` feature is available. This feature is enabled by default in v1.31+.

First, create a Kind cluster configuration file (`kind.yaml`):

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  image: kindest/node:v1.31.0
```

Then create the cluster:

```sh
kind create cluster --name crd-selectable-fields --config kind.yaml
```

## Define CRD

Let's create a CRD for a "Shirt" resource with selectable fields. The key part is the `selectableFields` section under each version, which declares which fields can be used in field selectors.

Here's our CRD definition (`crd.yaml`):

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: shirts.stable.example.com
spec:
  group: stable.example.com
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              color:
                type: string
              size:
                type: string
              price:
                type: integer
            required:
            - color
            - size
          status:
            type: object
            properties:
              available:
                type: boolean
    # This is the key feature - declaring selectable fields
    selectableFields:
    - jsonPath: .spec.color
    - jsonPath: .spec.size
    - jsonPath: .spec.price
    additionalPrinterColumns:
    - jsonPath: .spec.color
      name: Color
      type: string
    - jsonPath: .spec.size
      name: Size
      type: string
    - jsonPath: .spec.price
      name: Price
      type: integer
  scope: Namespaced
  names:
    plural: shirts
    singular: shirt
    kind: Shirt
```

The `selectableFields` section allows us to specify up to 8 fields that can be used in field selectors. 

**⚠️ Important Selectable Fields Constraints:**
- **Field Type Constraints**: Selectable fields must be of type `string`, `boolean`, or `integer`. The `number` type is **not supported**. In our example above, we use `type: integer` for the price field rather than `type: number`.
- **Scalar Values Only**: Selectable fields must reference scalar values, not objects or arrays.

Apply the CRD:

```sh
kubectl apply -f crd.yaml
```

Now let's create some shirt instances to demonstrate the field selector functionality.

## Add some objects

We'll create several shirt resources with different colors, sizes, and prices to test our field selectors.

Here's our shirts manifest (`shirts.yaml`):

```yaml
apiVersion: stable.example.com/v1
kind: Shirt
metadata:
  name: shirt-blue-small
spec:
  color: blue
  size: S
  price: 26
status:
  available: true
---
apiVersion: stable.example.com/v1
kind: Shirt
metadata:
  name: shirt-blue-medium
spec:
  color: blue
  size: M
  price: 28
status:
  available: true
---
apiVersion: stable.example.com/v1
kind: Shirt
metadata:
  name: shirt-red-large
spec:
  color: red
  size: L
  price: 30
status:
  available: false
---
apiVersion: stable.example.com/v1
kind: Shirt
metadata:
  name: shirt-green-medium
spec:
  color: green
  size: M
  price: 27
status:
  available: true
---
apiVersion: stable.example.com/v1
kind: Shirt
metadata:
  name: shirt-blue-large
spec:
  color: blue
  size: L
  price: 31
status:
  available: true
```

Let's apply these shirt resources to our cluster:

```sh
kubectl apply -f shirts.yaml
```

Let's verify that all our shirt resources have been created successfully:

```sh
kubectl get shirts
```

**Expected output:**

```text
NAME                 COLOR   SIZE   PRICE
shirt-blue-large     blue    L      31
shirt-blue-medium    blue    M      28
shirt-blue-small     blue    S      26
shirt-green-medium   green   M      27
shirt-red-large      red     L      30
```

Now we can demonstrate the power of field selectors with our custom resources.

## Query with field selectors

Let's use field selectors to query our shirt resources. First, let's find all blue shirts:

```sh
kubectl get shirts --field-selector spec.color=blue
```

**Expected output:**

```text
NAME                COLOR   SIZE   PRICE
shirt-blue-large    blue    L      31
shirt-blue-medium   blue    M      28
shirt-blue-small    blue    S      26
```

We can also combine multiple field selectors. Let's find all blue shirts in medium size:

```sh
kubectl get shirts --field-selector spec.color=blue,spec.size=M
```

**Expected output:**

```text
NAME                COLOR   SIZE   PRICE
shirt-blue-medium   blue    M      28
```

You can also use field selectors with other kubectl operations. For example, let's find shirts with a specific price:

```sh
kubectl get shirts --field-selector spec.price=27
```

**Expected output:**

```text
NAME                 COLOR   SIZE   PRICE
shirt-green-medium   green   M      27
```

## Additional Examples

Here are some more examples of field selectors in action:

Find all large shirts:
```sh
kubectl get shirts --field-selector spec.size=L
```

**Expected output:**
```text
NAME               COLOR   SIZE   PRICE
shirt-blue-large   blue    L      31
shirt-red-large    red     L      30
```

Find red large shirts:
```sh
kubectl get shirts --field-selector spec.color=red,spec.size=L
```

**Expected output:**
```text
NAME              COLOR   SIZE   PRICE
shirt-red-large   red     L      30
```

Search for non-existent items:
```sh
kubectl get shirts --field-selector spec.color=yellow
```

**Expected output:**
```text
No resources found in default namespace.
```

## Appendix

- [ChatGPT Answer](appendix-chatgpt-CRD-Selectable-Fields-Kubernetes.md)
- [Custrom Resources - Kubernetes official website](appendix-Custom-Resources-from-Kubernetes-official-website.md)