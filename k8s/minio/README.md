# MinIO

MinIO is the object storage layer of the lakehouse, providing S3-compatible storage for raw data, Iceberg table files, and intermediate results.

## Namespace

`storage`

## Buckets

| Bucket | Purpose |
| --- | --- |
| `warehouse` | Iceberg table data and metadata registered in Nessie |
| `staging` | Intermediate data during ingestion and transformation |
| `mlflow` | MLflow experiment tracking artifacts |

## Components

| File                  | Description                                     |
|-----------------------|-------------------------------------------------|
| `namespace.yaml`      | Namespace configuration                         |
| `secret.yaml`         | Sealed secret containing MinIO root credentials |
| `deployment.yaml`     | MinIO single-node deployment with PVC           |
| `minio-init-job.yaml` | One-off job to create buckets on first install  |
| `port-forward.sh`     | Script to forward MinIO ports to localhost      |

## Installation

### Generate credentials

Credentials are managed via Sealed Secrets. To create a sealed secret:

```bash
kubectl create secret generic minio-credentials \
  --namespace storage \
  --from-literal=MINIO_ROOT_USER=<<your-minio-username>> \
  --from-literal=MINIO_ROOT_PASSWORD=<<your-minio-password>> \
  --dry-run=client -o yaml | \
kubeseal --namespace storage --format yaml > secret.yaml
```

Apply in order:

```bash
kubectl apply -f namespace.yaml
kubectl apply -f secret.yaml
kubectl apply -f deployment.yaml
kubectl rollout status deployment/minio -n storage
kubectl apply -f service.yaml
kubectl apply -f minio-init-job.yaml
kubectl wait --for=condition=complete job/minio-init-setup -n storage --timeout=60s
```

Verify buckets were created:

```bash
kubectl logs job/minio-init-setup -n storage
```

## Accessing MinIO

### Console (browser)

```bash
./port-forward.sh
```

Then open [http://localhost:9001](http://localhost:9001) and log in with the root credentials.

### API (mc CLI)

```bash
mc alias set local http://localhost:9000 <root-user> <root-password>
mc ls local
```

### From within the cluster

Other services connect to MinIO using:

```
http://minio.storage.svc.cluster.local:9000
```

## Re-running bucket initialization

If you need to recreate the buckets (e.g. after a cluster reset), delete the completed job first:

```bash
kubectl delete job minio-init-setup -n storage --ignore-not-found
kubectl apply -f minio-init-job.yaml
```