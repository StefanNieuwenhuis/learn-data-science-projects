# Nessie

Nessie is the catalog layer of the lakehouse, providing Git-like versioning for Iceberg tables. It tracks table metadata - i.e. schema, partitioning, snapshots - and allows branching and merging of catalog state.

## Namespace

`catalog`

## Components

| File              | Description                                                    |
|-------------------|----------------------------------------------------------------|
| `namespace.yaml`  | Namespace configuration                                        |
| `deployment.yaml` | Nessie deployment with RocksDB persistence                     |
| `pvc.yaml`        | PersistentVolumeClaim for RocksDB data                         |
| `service.yaml`    | ClusterIP service exposing the Nessie API and management ports |

## Installation

```bash
kubectl apply -f namespace.yaml
kubectl apply -f pvc.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl rollout status deployment/nessie -n catalog
```

Verify Nessie is up:

```bash
kubectl port-forward svc/nessie 19120:19120 -n catalog
curl http://localhost:19120/api/v2/config
```

## Configuration

| Environment Variable | Value | Description |
| --- | --- | --- |
| `NESSIE_VERSION_STORE_TYPE` | `ROCKSDB` | Persistent storage backend |
| `QUARKUS_OTEL_SDK_DISABLED` | `true` | Disables OpenTelemetry |
| `JAVA_OPTS_APPEND` | see deployment.yaml | Sets RocksDB data path to PVC mount |

### RocksDB

Data is persisted at `/var/lib/nessie/data` inside the container, backed by a PVC. This survives pod restarts.

## Accessing Nessie

### Port-forward

```bash
./port-forward.sh
```

Then the API is available at [http://localhost:19120](http://localhost:19120).

### API examples

```bash
# List branches
curl http://localhost:19120/api/v2/trees

# Get default branch config
curl http://localhost:19120/api/v2/config

# List tables on main branch
curl http://localhost:19120/api/v2/trees/main/entries
```

### From within the cluster

Other services connect to Nessie using:

```
http://nessie.catalog.svc.cluster.local:19120/api/v1
```

## Branching workflow

Nessie supports Git-like branching for catalog changes. Useful for testing dbt transformations without affecting production tables:

```bash
# Create a feature branch
curl -X POST http://localhost:19120/api/v2/trees \
  -H "Content-Type: application/json" \
  -d '{"name":"feature-titanic","type":"BRANCH","reference":{"type":"BRANCH","name":"main"}}'

# List all branches
curl http://localhost:19120/api/v2/trees

# Merge back to main (via API or Nessie UI)
```

## Persistence

RocksDB data is stored on a PVC. To verify data survives a pod restart:

```bash
# Bounce the pod
kubectl rollout restart deployment/nessie -n catalog
kubectl rollout status deployment/nessie -n catalog

# Verify tables are still registered
curl http://localhost:19120/api/v2/trees/main/entries
```