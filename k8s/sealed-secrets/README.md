# Sealed Secrets

Sealed Secrets allows you to encrypt Kubernetes Secrets into `SealedSecret` resources that are safe to commit to Git. Only the controller running in the cluster can decrypt them.

## Components

- **Controller** — runs in `kube-system`, holds the master key, decrypts `SealedSecret` resources into regular `Secret` resources automatically
- **`kubeseal` CLI** — encrypts regular secrets into sealed secrets on your local machine

## Why kubeseal?

A standard Kubernetes `Secret` is only base64-encoded, not encrypted:

```yaml
apiVersion: v1
kind: Secret
data:
  password: bWluaW8xMjM=  # just base64 — anyone can decode this
```

This means you cannot safely commit secrets to Git. The moment a secret YAML file enters your repository, the credentials are exposed to anyone with read access — including CI systems, contributors, and anyone who ever clones the repo.

`kubeseal` solves this by encrypting the secret values using the controller's public key before you ever touch Git. The result is a `SealedSecret` resource whose encrypted values are meaningless without the master key held by the controller in your cluster:

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
spec:
  encryptedData:
    password: AgBy3i4OJSWK+PiTySYZZA...  # RSA-encrypted — safe to commit
```

The workflow becomes:

```
local machine           git repository          cluster
     │                       │                     │
     │  kubeseal encrypts     │                     │
     ├──────────────────────>│  SealedSecret yaml  │
     │                       ├────────────────────>│
     │                       │                     │ controller decrypts
     │                       │                     ├──> Secret (in memory)
```

For a lakehouse setup running in Kubernetes this matters particularly because you have multiple sensitive credentials scattered across namespaces — MinIO access keys, Nessie auth tokens, Dremio credentials, Spark S3 keys — and you want all your cluster configuration in Git as infrastructure-as-code without leaking any of them.

## Installation

### Controller

```bash
# controller source (latest version): https://github.com/bitnami-labs/sealed-secrets/releases/latest/download/controller.yaml
kubectl apply -f k8s/sealed-secrets/controller.yaml
```

Verify it's running:

```bash
kubectl get pods -n kube-system | grep sealed-secrets
```

### kubeseal CLI

**macOS:**
```bash
brew install kubeseal
```

**Linux:**
```bash
wget https://github.com/bitnami-labs/sealed-secrets/releases/latest/download/kubeseal-linux-amd64.tar.gz
tar xzf kubeseal-linux-amd64.tar.gz
sudo mv kubeseal /usr/local/bin/
```

Verify:
```bash
kubeseal --version
```

## Master Key

The controller generates the master key automatically on first boot. No manual setup required.

### Backup

Back up the master key after installation and store it somewhere safe. Without it, sealed secrets cannot be decrypted on a new cluster.

```bash
kubectl get secret -n kube-system \
  -l sealedsecrets.bitnami.com/sealed-secrets-key \
  -o yaml > sealed-secrets-master-key-backup.yaml
```

> **Never commit this file to Git.**

### Restore on a new cluster

Apply the backup before or after the controller starts, then restart the controller:

```bash
kubectl apply -f sealed-secrets-master-key-backup.yaml
kubectl rollout restart deployment sealed-secrets-controller -n kube-system
```

## Usage

### Sealing a secret

Never apply the plain secret to the cluster. Pipe it directly into `kubeseal`:

```bash
kubectl create secret generic my-secret \
  --namespace my-namespace \
  --from-literal=username=myuser \
  --from-literal=password=mypassword \
  --dry-run=client -o yaml | \
kubeseal \
  --controller-namespace kube-system \
  --controller-name sealed-secrets-controller \
  --namespace my-namespace \
  --format yaml > my-secret-sealed.yaml
```

Apply the sealed secret:

```bash
kubectl apply -f my-secret-sealed.yaml
```

The controller automatically decrypts it into a regular `Secret` in the same namespace.

### Verify decryption

```bash
kubectl get secret my-secret -n my-namespace
```

### Sealing from an existing file

```bash
kubeseal \
  --controller-namespace kube-system \
  --format yaml \
  < plain-secret.yaml \
  > sealed-secret.yaml
```

## Examples

### MinIO credentials

```bash
kubectl create secret generic minio-credentials \
  --namespace lakehouse \
  --from-literal=root-user=minio \
  --from-literal=root-password=minio123 \
  --dry-run=client -o yaml | \
kubeseal --namespace lakehouse --format yaml > k8s/sealed-secrets/minio-credentials-sealed.yaml
```

### Spark S3 credentials

```bash
kubectl create secret generic minio-credentials \
  --namespace spark \
  --from-literal=access-key=minio \
  --from-literal=secret-key=minio123 \
  --dry-run=client -o yaml | \
kubeseal --namespace spark --format yaml > k8s/sealed-secrets/spark-minio-credentials-sealed.yaml
```

## Important Notes

- Sealed secrets are **namespace-scoped** by default — a secret sealed for `lakehouse` cannot be used in `spark`
- Re-seal secrets for each namespace separately
- The encrypted value changes every time you run `kubeseal`, even with the same input — this is expected
- Sealed secrets can be safely committed to Git and are useless without the master key