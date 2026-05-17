# Spark Connect Server

Spark Connect is the processing layer of the lakehouse, providing a gRPC-based remote Spark session for ingestion and transformation jobs. Rust ingestion scripts connect to it via the `spark_connect_rs` client to read from MinIO and write Iceberg tables registered in Nessie.

## Namespace

`spark`

## Components

| File | Description |
| --- | --- |
| `namespace.yaml` | Namespace configuration |
| `spark-credentials.sealed.secret.yaml` | Sealed secret containing MinIO credentials |
| `rbac.yaml` | ServiceAccount and ClusterRoleBinding for Spark executor pods |
| `deployment.yaml` | Spark Connect server Deployment and Service |
| `Dockerfile` | Custom image with Iceberg, Nessie, S3A, and AWS SDK jars |

## Custom Docker Image

The official `apache/spark` image does not include the jars required for Iceberg, Nessie, and MinIO. A custom image must be built before deploying.

Since minikube has its own Docker daemon, build directly into it:

```bash
eval $(minikube docker-env)
docker build -t spark-connect-server:4.1.1 k8s/spark/
```

The image includes:

| Jar | Version | Purpose |
| --- | --- | --- |
| `iceberg-spark-runtime-4.0_2.13` | 1.10.1 | Iceberg Spark extensions and NessieCatalog |
| `iceberg-aws-bundle` | 1.10.1 | Iceberg S3FileIO for MinIO |
| `hadoop-aws` | 3.4.2 | S3AFileSystem for `s3a://` paths |
| `aws-sdk-bundle` | 2.35.4 | AWS SDK v2 runtime for hadoop-aws 3.4.x |

## Installation

### Generate credentials

Credentials are managed via Sealed Secrets. To create a sealed secret:

```bash
kubectl create secret generic spark-minio-credentials \
  --namespace spark \
  --from-literal=access-key=<<your-minio-access-key>> \
  --from-literal=secret-key=<<your-minio-secret-key>> \
  --dry-run=client -o yaml | \
kubeseal --namespace spark --format yaml > spark-credentials.sealed.secret.yaml
```

Apply in order:

```bash
eval $(minikube docker-env)
docker build -t spark-connect-server:4.1.1 .
kubectl apply -f namespace.yaml
kubectl apply -f rbac.yaml
kubectl apply -f spark-credentials.sealed.secret.yaml
kubectl apply -f deployment.yaml
kubectl rollout status deployment/spark-connect-server -n spark
```

Verify Spark Connect started:

```bash
kubectl logs deployment/spark-connect-server -n spark | grep "SparkConnect"
```

## Accessing Spark Connect

### From Rust ingestion scripts

```bash
kubectl port-forward svc/spark-connect 15002:15002 -n spark
```

Then connect from Rust:

```rust
let spark = SparkSessionBuilder::remote("sc://localhost:15002")
    .build()
    .await?;
```

### Spark UI

```bash
kubectl port-forward svc/spark-connect 4040:4040 -n spark
# Open http://localhost:4040
```

### From within the cluster

Other services connect to Spark Connect using:

```
sc://spark-connect.spark.svc.cluster.local:15002
```

## Configuration

`spark-defaults.conf` is generated at pod startup by an init container that reads credentials from the sealed secret. It configures:

- Iceberg Spark extensions
- Nessie catalog pointing to `http://nessie.catalog.svc.cluster.local:19120/api/v2`
- S3FileIO for Iceberg using MinIO
- Hadoop S3A filesystem for `s3a://` URIs

The non-sensitive parts of the config (endpoints, catalog settings) are visible in `deployment.yaml`. Credentials never appear in any manifest.

## Re-deploying

If you need to redeploy (e.g. after a cluster reset), rebuild the image first:

```bash
eval $(minikube docker-env)
docker build -t spark-connect-server:4.1.1 .
kubectl rollout restart deployment/spark-connect-server -n spark
```

If you change the Dockerfile (e.g. upgrade jar versions), bump the image tag in `deployment.yaml` accordingly to avoid minikube serving a stale cached image.