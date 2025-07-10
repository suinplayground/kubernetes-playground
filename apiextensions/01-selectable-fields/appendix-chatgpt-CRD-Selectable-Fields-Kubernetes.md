### Short answer

Yes — **field selectors for Custom Resources *do* work**, provided your cluster is on **Kubernetes v1.31 or newer** and the CRD is written correctly.
If you are on an earlier release, or omitted the `selectableFields` stanza, they will appear “broken” because the API server simply ignores any selector other than `metadata.name` / `metadata.namespace`.

---

### How it works today (Kubernetes v1.31+)

| Release   | Feature-gate                   | Default       | Notes                                                            |
| --------- | ------------------------------ | ------------- | ---------------------------------------------------------------- |
| **v1.31** | `CustomResourceFieldSelectors` | **ON** (beta) | first version where CRDs can declare extra selectable fields     |
| **v1.32** | GA / stable                    | **ON**        | feature promoted to Stable; no flags needed ([Alibaba Cloud][1]) |

With the gate enabled, the API server consults a new list that CRD authors can put under each version:

```yaml
spec:
  versions:
  - name: v1
    selectableFields:
      - jsonPath: .spec.color
      - jsonPath: .spec.size
```

* Up to **8 paths** may be listed ([Kubernetes][2])
* Paths must use **dot notation**, reference **scalar fields** (string / int / bool), and **cannot touch `metadata.*`**
* Once declared, every normal list / watch call supports the extra selectors:

```bash
kubectl get shirts \
  --field-selector spec.color=blue,spec.size=M
```

This works exactly like built-in selectors, returning and streaming only the matching objects ([Kubernetes][3]).

---

### Why it may look like it “doesn’t work”

1. **Older control-planes (< v1.31) or feature gate off** – the API server silently drops unsupported selectors.
2. **CRD not updated** – if the CRD YAML lacks the `selectableFields` list, only `metadata.name/namespace` are selectable.
3. **Invalid JSONPath** – arrays (`[0]`), wildcard (`*`), or complex objects are rejected.
4. **More than 8 fields** – the API server will fail the CRD admission.
5. **Client-side kubectl cache** – `kubectl get --cache=false …` can help while testing.

---

### Quick checklist to make it work

1. **Verify cluster version**

```bash
kubectl version --short
# Server Version: v1.32.x       ← needs to be ≥ v1.31
```

2. **Confirm feature gate (for completeness)**

```bash
kubectl -n kube-system get pods -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}'
# should NOT contain --feature-gates=CustomResourceFieldSelectors=false
```

3. **Patch / apply CRD with `selectableFields`** (example above).
4. **Create or update instances** – changes only apply to new edits; existing objects still match as long as the field holds the value.
5. **Test with kubectl or your client library**.

---

### Limitations & best-practice tips

* **Watch, list, and DeleteCollection** respect the selectors; **Get / Update / Patch** do not.
* **No range or set operators** (yet) – only `key=val` or `key!=val`.
* Indexes in controller caches still need explicit informers; field selectors don’t add automatic indexes.
* Remember that **labels** remain the most portable way to query across clusters and versions; use field selectors when you need queries on immutable spec fields.

---

### Bottom line

If your cluster is on **v1.31+**, declare the paths in `spec.versions[*].selectableFields`, and field selectors against those paths will work exactly like they do for Pods or Deployments. If you’re stuck on an older version, you’ll need to upgrade or back-port the feature gate to use this capability.

[1]: https://www.alibabacloud.com/help/en/ack/ack-managed-and-ack-dedicated/user-guide/kubernetes-1-32-release-notes?utm_source=chatgpt.com "Kubernetes 1.32 release notes - Container Service ... - Alibaba Cloud"
[2]: https://kubernetes.io/zh-cn/docs/reference/kubernetes-api/extend-resources/custom-resource-definition-v1/ "CustomResourceDefinition | Kubernetes"
[3]: https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/?utm_source=chatgpt.com "Extend the Kubernetes API with CustomResourceDefinitions"
