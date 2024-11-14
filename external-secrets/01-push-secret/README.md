# Sync Kubernetes Secrets to AWS Secrets Manager Using external-secrets PushSecret

When managing sensitive information in Kubernetes, you can use an operator called [external-secrets](https://external-secrets.io/) to integrate with external secret providers like AWS Secrets Manager.

While the common usage pattern is to synchronize sensitive information stored in AWS Secrets Manager as Kubernetes Secrets, this article introduces `PushSecret`, which enables reverse synchronization - pushing Kubernetes Secrets to AWS Secrets Manager.

Let's explore the basic usage of `PushSecret`.

## Prerequisites

- Kubernetes cluster
- AWS account
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/)
- [AWS CLI](https://aws.amazon.com/cli/)

## Installing external-secrets

First, install external-secrets using Helm:

```bash
helm repo add external-secrets https://charts.external-secrets.io

helm install external-secrets \
   external-secrets/external-secrets \
    -n external-secrets \
    --create-namespace
```

## Setting Up AWS Credentials

Set AWS credentials as environment variables and verify they are configured correctly:

```bash
export AWS_ACCESS_KEY_ID=xxxx
export AWS_SECRET_ACCESS_KEY=xxxx
export AWS_REGION=ap-northeast-1

# Verify credentials
aws sts get-caller-identity
```

Next, store these credentials as a Kubernetes Secret:

```bash
kubectl create secret generic aws-credentials \
  --from-literal=access-key-id=${AWS_ACCESS_KEY_ID} \
  --from-literal=secret-access-key=${AWS_SECRET_ACCESS_KEY}
```

## Configuring SecretStore

Create a `SecretStore` to connect to AWS Secrets Manager:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secretsmanager
  namespace: default
spec:
  provider:
    aws:
      service: SecretsManager
      region: ap-northeast-1
      auth:
        secretRef:
          accessKeyIDSecretRef:
            name: aws-credentials
            key: access-key-id
          secretAccessKeySecretRef:
            name: aws-credentials
            key: secret-access-key
```

```bash
kubectl apply -f secret-store.yaml
```

## Configuring PushSecret

Create a `PushSecret` to synchronize Kubernetes Secrets to AWS Secrets Manager:

```yaml
apiVersion: external-secrets.io/v1alpha1
kind: PushSecret
metadata:
  name: pushsecret-example
  namespace: default
spec:
  # Overwrite existing secrets in provider during sync
  updatePolicy: Replace
  # Delete provider secrets when PushSecret is deleted
  deletionPolicy: Delete
  # Resync interval
  refreshInterval: 10s
  # SecretStore to push secrets to
  secretStoreRefs:
    - name: aws-secretsmanager
      kind: SecretStore
  # Target Secret for synchronization
  selector:
    secret:
      name: my-secret
  # Key configuration for synchronization
  data:
    - match:
        secretKey: foo  # Secret key
        remoteRef:
          remoteKey: my-secret-foo  # AWS Secrets Manager secret name
      metadata:
        secretPushFormat: string
```

```bash
kubectl apply -f push-secret.yaml
```

## Verification

### 1. Creating a Secret

First, create the target Secret:

```bash
kubectl create secret generic my-secret \
  --from-literal=foo=bar
```

Verify that it has been synchronized to AWS Secrets Manager:

```bash
aws secretsmanager get-secret-value \
  --secret-id my-secret-foo
```

If successful, you should see a response like this:

```json
{
    "ARN": "arn:aws:secretsmanager:ap-northeast-1:000000000000:secret:my-secret-foo-rUBCkr",
    "Name": "my-secret-foo",
    "VersionId": "00000000-0000-0000-0000-000000000001",
    "SecretString": "bar",
    "VersionStages": [
        "AWSCURRENT"
    ],
    "CreatedDate": "2024-11-14T09:50:34.787000+09:00"
}
```

### 2. Updating the Secret

Let's update the Secret value:

```bash
kubectl create secret generic my-secret \
  --from-literal=foo=baz \
  --dry-run=client -o yaml | kubectl apply -f -
```

Verify that the value has been updated in AWS Secrets Manager:

```bash
aws secretsmanager get-secret-value \
  --secret-id my-secret-foo
```

You can confirm that `SecretString` has changed from `bar` to `baz`:

```json
{
    "ARN": "arn:aws:secretsmanager:ap-northeast-1:000000000000:secret:my-secret-foo-rUBCkr",
    "Name": "my-secret-foo",
    "VersionId": "00000000-0000-0000-0000-000000000002",
    "SecretString": "baz",
    "VersionStages": [
        "AWSCURRENT"
    ],
    "CreatedDate": "2024-11-14T10:03:41.913000+09:00"
}
```

### 3. Verifying Deletion Behavior

Delete the Secret:

```bash
kubectl delete secret my-secret
```

At this point, the secret in AWS Secrets Manager is not deleted.

Next, delete the PushSecret:

```bash
kubectl delete pushsecret pushsecret-example
```

This operation will also delete the secret from AWS Secrets Manager:

```bash
aws secretsmanager list-secrets
```

```json
{
    "SecretList": []
}
```

## Cleanup

When you delete the external-secrets `PushSecret`, `my-secret-foo` remains in AWS Secrets Manager as "scheduled for deletion". To immediately delete the secret from AWS Secrets Manager:

```bash
aws secretsmanager delete-secret \
  --secret-id my-secret-foo \
  --force-delete-without-recovery
```

Delete external-secrets:

```bash
helm uninstall external-secrets -n external-secrets
```

Delete AWS credentials:

```bash
kubectl delete secret aws-credentials
```

## Summary

We've seen how external-secrets' `PushSecret` can synchronize Kubernetes Secrets to AWS Secrets Manager. This feature can be useful in several scenarios:

- Sharing sensitive information managed in Kubernetes with other AWS services
- Sharing Secrets between Kubernetes clusters via AWS Secrets Manager
- Backing up Kubernetes Secrets to AWS Secrets Manager

While this example used external-secrets with AWS Secrets Manager, there are various other providers available for SecretStore. One particularly interesting provider is Kubernetes itself. I'm personally interested in trying out direct Secret synchronization between Kubernetes clusters and plan to write about that experience in a future article.

## Reference Links

- [external-secrets Official Documentation](https://external-secrets.io/)
- [PushSecret Reference](https://external-secrets.io/latest/api/pushsecret/)
