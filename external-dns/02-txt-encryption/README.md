# Securing external-dns: Encrypting TXT Registry Records

In my [previous article](https://dev.to/suin/automated-dns-record-management-for-kubernetes-resources-using-external-dns-and-aws-route53-cnm), we explored how to automate DNS record management using external-dns with AWS Route53. We briefly mentioned that management information stored in TXT records is publicly visible. Today, let's dive into how to secure this information using external-dns's TXT record encryption feature.

## Understanding TXT Registry in external-dns

external-dns stores management information in what's called a Registry. While multiple Registry options exist, including DynamoDB and AWS Service Discovery, TXT Registry is particularly interesting because it avoids cloud vendor lock-in. However, since TXT records are publicly accessible, encrypting them adds an important security layer while maintaining the benefits of vendor independence.

## Prerequisites

- A configured Kubernetes cluster
- Required command-line tools installed:
    - kubectl
    - helm
    - aws
    - dig
- AWS account access and secret keys

## Implementation Steps

### 1. Creating an AWS Route53 Hosted Zone

First, set your AWS credentials as environment variables:

```bash
export AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXXXXXXXX
export AWS_SECRET_ACCESS_KEY=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

Verify your AWS credentials:

```bash
aws sts get-caller-identity
```

Create a Hosted Zone:

```bash
aws route53 create-hosted-zone --name example-tutorial.com --caller-reference external-dns-tutorial-$(date +%s)
```

**Note:** The caller-reference must be unique for each creation attempt. We're using a timestamp to ensure uniqueness.

### 2. Installing external-dns with TXT Encryption

We'll use Bitnami's Helm chart as it offers more configuration options and simplifies AWS Route53 setup compared to the kubernetes-sigs chart:

```bash
helm install external-dns \
  --set provider=aws \
  --set aws.zoneType=public \
  --set aws.credentials.accessKey="$AWS_ACCESS_KEY_ID" \
  --set aws.credentials.secretKey="$AWS_SECRET_ACCESS_KEY" \
  --set txtOwnerId=example-owner-id-123 \
  --set "domainFilters[0]=example-tutorial.com" \
  --set policy=sync \
  --set "sources[0]=crd" \
  --set crd.create=true \
  --set crd.apiversion=externaldns.k8s.io/v1alpha1 \
  --set crd.kind=DNSEndpoint \
  --set txtEncrypt.enabled=true \
  --set txtEncrypt.aesKey="" \
  oci://registry-1.docker.io/bitnamicharts/external-dns
```

#### Installation Options Explained

| Option | Description |
|--------|-------------|
| `provider=aws` | Specifies AWS Route53 as the provider |
| `aws.zoneType=public` | Specifies the use of a public zone |
| `aws.credentials.accessKey` | AWS access key |
| `aws.credentials.secretKey` | AWS secret key |
| `txtOwnerId` | TXT record owner ID (can be any value) |
| `domainFilters[0]` | Domain to monitor |
| `policy=sync` | DNS record synchronization policy |
| `sources[0]=crd` | Enables CRD usage |
| `crd.create=true` | Creates the CRD |
| `crd.apiversion` | CRD API version |
| `crd.kind` | CRD kind |
| `txtEncrypt.enabled=true` | Enables TXT record encryption |
| `txtEncrypt.aesKey` | AES key for encryption (auto-generated if empty) |

After installation, verify that external-dns is running with encryption enabled:

```bash
kubectl logs -l app.kubernetes.io/name=external-dns -f
```

You should see logs indicating encrypted TXT records are enabled:

```
time="2024-11-06T07:03:47Z" level=info msg="config: {...TXTEncryptEnabled:true...}"
time="2024-11-06T07:03:47Z" level=info msg="Instantiating new Kubernetes client"
time="2024-11-06T07:03:47Z" level=info msg="Using inCluster-config based on serviceaccount-token"
time="2024-11-06T07:03:47Z" level=info msg="Created Kubernetes client https://10.43.0.1:443"
time="2024-11-06T07:03:49Z" level=info msg="Applying provider record filter for domains: [example-tutorial.com. .example-tutorial.com.]"
```

Verify that the AES encryption key was generated and stored in the secret:

```bash
kubectl get secret external-dns -o yaml
```

You should see the `txt_aes_encryption_key` field in the secret data:

```yaml
apiVersion: v1
kind: Secret
data:
  txt_aes_encryption_key: Q2NCSUF6c2I1N215SGY4RWZtWmZvWm1keUl2SHBsTDY=  # Base64 encoded AES key
# ... other fields omitted for brevity
```

### 3. Creating DNS Records

Let's verify that external-dns creates encrypted DNS records. We'll use the DNSEndpoint CRD as it requires no actual resources:

```yaml
# test.example-tutorial.com.yaml
apiVersion: externaldns.k8s.io/v1alpha1
kind: DNSEndpoint
metadata:
  name: test.example-tutorial.com
spec:
  endpoints:
  - dnsName: test.example-tutorial.com
    recordTTL: 180
    recordType: A
    targets:
    - 127.0.0.1
```

Apply the manifest:

```bash
kubectl apply -f test.example-tutorial.com.yaml
```

After a moment, external-dns will create the DNS records. Check the logs:

```
time="2024-11-06T07:12:52Z" level=info msg="Desired change: CREATE a-test.example-tutorial.com TXT" profile=default zoneID=/hostedzone/Z00418233KGBJI8AZJFPR zoneName=example-tutorial.com.
time="2024-11-06T07:12:52Z" level=info msg="Desired change: CREATE test.example-tutorial.com A" profile=default zoneID=/hostedzone/Z00418233KGBJI8AZJFPR zoneName=example-tutorial.com.
time="2024-11-06T07:12:52Z" level=info msg="2 record(s) were successfully updated" profile=default zoneID=/hostedzone/Z00418233KGBJI8AZJFPR zoneName=example-tutorial.com.
```

Verify the DNS records using AWS CLI:

```bash
aws route53 list-resource-record-sets --hosted-zone-id Z00418233KGBJI8AZJFPR
```

You should see both the A record and the encrypted TXT record:

```json
{
    "ResourceRecordSets": [
        {
            "Name": "test.example-tutorial.com.",
            "Type": "A",
            "TTL": 180,
            "ResourceRecords": [
                {
                    "Value": "127.0.0.1"
                }
            ]
        },
        {
            "Name": "a-test.example-tutorial.com.",
            "Type": "TXT",
            "TTL": 300,
            "ResourceRecords": [
                {
                    "Value": "\"YwPTDxmRgtKjryuSqYrqA35DoRkFw94ZxoojvZ9goHiyXbd8zYS8wBqS7t3ZtZoqREqDDaLtLcB0wbzTpw9n1+HxgGrJc795b4ISnJXRI03+sJ+DgN71dU7hCCyoPx25w/jYbOX3/zP DP59BmZaAly/OLmCEcDTW7dl697qdj4lsNHBrr+6Z1lAFKHAKfX3pM9w6RFGmpGl4WULtAA==\""
                }
            ]
        }
    ]
}
```

With TXT encryption enabled (`txtEncrypt.enabled=true`), the TXT record content is encrypted using AES encryption. While it still contains the same management information (heritage, owner, and resource), it's now secured from unauthorized access.

### Cleanup

#### 1. Removing DNS Records

Delete the CRD resource:

```bash
kubectl delete -f test.example-tutorial.com.yaml
```

external-dns will remove the DNS records shortly after. Check the logs:

```
time="2024-11-06T05:48:24Z" level=info msg="Desired change:  DELETE  a-test.example-tutorial.com TXT" profile=default zoneID=/hostedzone/Z08033563HFN15GSXJ766 zoneName=example-tutorial.com.
time="2024-11-06T05:48:24Z" level=info msg="Desired change:  DELETE  test.example-tutorial.com A" profile=default zoneID=/hostedzone/Z08033563HFN15GSXJ766 zoneName=example-tutorial.com.
time="2024-11-06T05:48:24Z" level=info msg="Desired change:  DELETE  test.example-tutorial.com TXT" profile=default zoneID=/hostedzone/Z08033563HFN15GSXJ766 zoneName=example-tutorial.com.
time="2024-11-06T05:48:24Z" level=info msg="3 record(s) were successfully updated" profile=default zoneID=/hostedzone/Z08033563HFN15GSXJ766 zoneName=example-tutorial.com.
```

#### 2. Removing external-dns

Delete the Helm release:

```bash
helm uninstall external-dns
```

#### 3. Removing the Hosted Zone

First, list the zones:

```bash
aws route53 list-hosted-zones
```

Then delete the zone using its ID:

```bash
aws route53 delete-hosted-zone --id Z00418233KGBJI8AZJFPR
```

## Conclusion

In this article, we've explored how to secure external-dns management information by implementing TXT record encryption. While TXT Registry offers a vendor-independent way to store management information, encryption adds an essential security layer. By following these steps, you can maintain the benefits of TXT Registry while ensuring your management information remains secure.

When combined with the setup described in the [previous article](https://dev.to/suin/automated-dns-record-management-for-kubernetes-resources-using-external-dns-and-aws-route53-cnm), you'll have a robust and secure DNS automation solution. Give it a try in your environment!