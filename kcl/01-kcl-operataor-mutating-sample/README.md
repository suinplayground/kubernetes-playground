# KCL Operator Mutating Sample

This sample demonstrates how to use KCL operator to mutate Kubernetes resources.

## Files

* `pod.k` - Defines a sample Pod that runs an echo server
* `kcl-run.k` - Creates a KCLRun resource that configures the KCL operator with our mutation logic
* `pod-mutator/main.k` - Contains the mutation logic that adds two annotations to every Pod:
  * `test/updated-by`: Set to "kcl-operator"
  * `test/updated-at`: Set to the current timestamp

## How to Test

1. Install KCL operator:
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kcl-lang/kcl-operator/main/config/all.yaml
   ```

2. Apply the KCL operator configuration:
   ```bash
   kcl run kcl-run.k | kubectl apply -f -
   ```

3. Add UPDATE operation to the webhook:
   ```bash
   kubectl patch mutatingwebhookconfiguration kcl-webhook-server --type='json' -p='[{"op": "add", "path": "/webhooks/0/rules/0/operations/-", "value": "UPDATE"}]'
   ```

4. Apply the sample Pod:
   ```bash
   kcl run pod.k -O metadata.labels.nonce:\'$(date +%s)\' | kubectl apply -f -
   ```

5. Check the result:
   ```bash
   kubectl get po echo -o yaml | yq .metadata.annotations
   ```

You should see that the Pod has a new label `updated-at` and `updated-by`:

```yaml
test/updated-at: Tue Dec 17 00:57:35 2024
test/updated-by: kcl-operator
```

## How it Works

1. The KCL operator watches for new KCLRun resources in the cluster
2. When we apply `kcl-run.k`, it creates a KCLRun resource named "pod-mutator" that contains our mutation logic
3. The mutation logic in `pod-mutator/main.k` is a simple function that adds two annotations to any Pod:
   * `test/updated-by`: To track which component made the change
   * `test/updated-at`: To record when the change was made
4. When we create a Pod using `pod.k`, the KCL operator:
   * Intercepts the Pod creation
   * Runs our mutation logic
   * Adds the annotations before the Pod is created in the cluster

This demonstrates how KCL operator can be used to automatically modify Kubernetes resources.
