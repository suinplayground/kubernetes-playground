# external-dns with AWS Route53

This demo explains how to use external-dns with AWS Route53.

## Prerequisites

- A configured Kubernetes cluster
- Required command-line tools installed:
    - kubectl
    - helm
    - aws
    - dig

## What is external-dns?

external-dns is a tool that monitors Kubernetes resources and automatically updates DNS records.

## What is AWS Route53?

AWS Route53 is AWS's managed DNS service.

## Steps

### Creating an AWS Route53 Hosted Zone

Set your AWS credentials as environment variables:

```bash
export AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXXXXXXXX
export AWS_SECRET_ACCESS_KEY=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

Verify your AWS credentials:

```bash
aws sts get-caller-identity
```

Create a Hosted Zone using the AWS CLI:

```bash
aws route53 create-hosted-zone --name example-tutorial.com --caller-reference external-dns-tutorial
```

### Installing external-dns

While kubernetes-sigs provides a Helm chart for external-dns, we'll use the one provided by Bitnami as it offers more options and makes AWS Route53 configuration easier.

```bash
helm install external-dns \
  --set provider=aws \
  --set aws.zoneType=public \
  --set aws.credentials.accessKey="$AWS_ACCESS_KEY_ID" \
  --set aws.credentials.secretKey="$AWS_SECRET_ACCESS_KEY" \
  --set txtOwnerId=Z02282193L1WY4Z5MBFLU \
  --set "domainFilters[0]=example-tutorial.com" \
  --set policy=sync \
  --set "sources[0]=crd" \
  --set crd.create=true \
  --set crd.apiversion=externaldns.k8s.io/v1alpha1 \
  --set crd.kind=DNSEndpoint \
  oci://registry-1.docker.io/bitnamicharts/external-dns
```

#### Option Explanations

- `provider=aws`: Specifies the use of AWS Route53
- `aws.zoneType=public`: Specifies the use of a public zone
- `aws.credentials.accessKey`: AWS access key
- `aws.credentials.secretKey`: AWS secret key
- `txtOwnerId=EXAMPLE-ZONE-ID123`: TXT record owner ID (role explained later)
- `domainFilters[0]=example-tutorial.com`: Specifies the domain to monitor
- `policy=sync`: Specifies the sync policy
- `sources[0]=crd`: Specifies the use of CRD
- `crd.create=true`: Creates the CRD
- `crd.apiversion=externaldns.k8s.io/v1alpha1`: Specifies the CRD API version
- `crd.kind=DNSEndpoint`: Specifies the CRD kind

After a moment, external-dns will start. Check the logs:

```bash
kubectl logs -l app.kubernetes.io/name=external-dns -f
```

You should see logs similar to this, indicating external-dns has started successfully:

```bash
time="2024-11-06T05:12:29Z" level=info msg="Instantiating new Kubernetes client"
time="2024-11-06T05:12:29Z" level=info msg="Using inCluster-config based on serviceaccount-token"
time="2024-11-06T05:12:29Z" level=info msg="Created Kubernetes client https://10.43.0.1:443"
time="2024-11-06T05:12:31Z" level=info msg="Applying provider record filter for domains: [example-tutorial.com. .example-tutorial.com.]"
```

### Creating Records with external-dns

Let's verify that external-dns creates DNS records from Kubernetes resources.

external-dns monitors resources like Services, Ingress, and Gateway to create DNS records. In this example, we'll use the DNSEndpoint CRD.

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

```bash
kubectl apply -f test.example-tutorial.com.yaml
```

Shortly after, external-dns will create the DNS records. Check the logs:

```
time="2024-11-06T05:32:15Z" level=info msg="Desired change: CREATE a-test.example-tutorial.com TXT" profile=default zoneID=/hostedzone/Z08033563HFN15GSXJ766 zoneName=example-tutorial.com.
time="2024-11-06T05:32:15Z" level=info msg="Desired change: CREATE test.example-tutorial.com A" profile=default zoneID=/hostedzone/Z08033563HFN15GSXJ766 zoneName=example-tutorial.com.
time="2024-11-06T05:32:15Z" level=info msg="Desired change: CREATE test.example-tutorial.com TXT" profile=default zoneID=/hostedzone/Z08033563HFN15GSXJ766 zoneName=example-tutorial.com.
time="2024-11-06T05:32:15Z" level=info msg="3 record(s) were successfully updated" profile=default zoneID=/hostedzone/Z08033563HFN15GSXJ766 zoneName=example-tutorial.com.
```

Verify that the DNS record was created. Note that `@ns-1694.awsdns-19.co.uk` is the AWS Route53 nameserver hostname. This will vary based on your Hosted Zone configuration:

```bash
dig @ns-1694.awsdns-19.co.uk +noall +answer -t A test.example-tutorial.com
```

You should see output like this, indicating the DNS record was created successfully:

```bash
test.example-tutorial.com. 180  IN      A       127.0.0.1
```

Also verify the TXT record:

```bash
dig @ns-1694.awsdns-19.co.uk +noall +answer -t TXT test.example-tutorial.com
```

```
test.example-tutorial.com. 300  IN      TXT     "heritage=external-dns,external-dns/owner=EXAMPLE-ZONE-ID123,external-dns/resource=crd/default/test.example-tutorial.com"
```

This TXT record is created by external-dns for management purposes. It contains:

1. `heritage=external-dns`
    - Indicates this DNS record was created and is managed by external-dns
2. `external-dns/owner=EXAMPLE-ZONE-ID123`
    - Shows the owner ID, in this case "EXAMPLE-ZONE-ID123"
    - Used to identify specific external-dns instances
    - Prevents conflicts when multiple external-dns instances exist
3. `external-dns/resource=crd/default/test.example-tutorial.com`
    - Shows the Kubernetes resource that created this DNS record
    - In this case, it references a CRD resource named `test.example-tutorial.com` in the `default` namespace

While this management information is publicly visible in TXT records, encryption options may be available (requires further investigation).

### Deleting Records

To delete DNS records, remove the CRD resource:

```bash
kubectl delete -f test.example-tutorial.com.yaml
```

external-dns will delete the DNS records shortly after. Check the logs:

```
time="2024-11-06T05:48:24Z" level=info msg="Desired change:  DELETE  a-test.example-tutorial.com TXT" profile=default zoneID=/hostedzone/Z08033563HFN15GSXJ766 zoneName=example-tutorial.com.
time="2024-11-06T05:48:24Z" level=info msg="Desired change:  DELETE  test.example-tutorial.com A" profile=default zoneID=/hostedzone/Z08033563HFN15GSXJ766 zoneName=example-tutorial.com.
time="2024-11-06T05:48:24Z" level=info msg="Desired change:  DELETE  test.example-tutorial.com TXT" profile=default zoneID=/hostedzone/Z08033563HFN15GSXJ766 zoneName=example-tutorial.com.
time="2024-11-06T05:48:24Z" level=info msg="3 record(s) were successfully updated" profile=default zoneID=/hostedzone/Z08033563HFN15GSXJ766 zoneName=example-tutorial.com.
```

Verify that the DNS record was deleted:

```bash
dig @ns-1694.awsdns-19.co.uk +noall +answer -t A test.example-tutorial.com
```

### Cleanup

To remove external-dns, delete the Helm release:

```bash
helm uninstall external-dns
```

To delete the AWS Route53 Hosted Zone, first list the zones:

```bash
aws route53 list-hosted-zones
```

Then delete the zone using its ID:

```bash
aws route53 delete-hosted-zone --id Z08033563HFN15GSXJ766
```