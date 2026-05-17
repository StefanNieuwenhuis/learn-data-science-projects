# Dremio

Dremio is the query engine of the lakehouse, providing a SQL interface over Iceberg tables registered in Nessie. It connects directly to MinIO for data access and Nessie for catalog metadata.

## Namespace

`query`

## Components

| File                                    | Description                                       |
|-----------------------------------------|---------------------------------------------------|
| `namespace.yaml`                        | Namespace configuration                           |
| `dremio-credentials.sealed.secret.yaml` | Sealed secret containing MinIO credentials        |
| `configmap.yaml`                        | `dremio.conf` configuration                       |
| `statefulset.yaml`                      | Dremio master coordinator StatefulSet |
| `service.yaml`                          | Dremio master coordinator Service                                 |

## Installation

### Generate credentials

Credentials are managed via Sealed Secrets. To create a sealed secret:

```bash
kubectl create secret generic dremio-minio-credentials \
  --namespace query \
  --from-literal=access-key=<<your-minio-access-key>> \
  --from-literal=secret-key=<<your-minio-secret-key>> \
  --dry-run=client -o yaml | \
kubeseal --namespace dremio --format yaml > secret.yaml
```

Apply in order:

```bash
kubectl apply -f namespace.yaml
kubectl apply -f dremio-credentials.sealed.secret.yaml
kubectl apply -f configmap.yaml
kubectl apply -f statefulset.yaml
kubectl apply -f service.yaml
```

Verify Dremio started successfully:

```bash
kubectl logs dremio-master-coordinator-0 -n query | grep "Started on"
```

## Accessing Dremio

### UI (browser)

```bash
kubectl port-forward svc/dremio 9047:9047 -n query
```

Then open [http://localhost:9047](http://localhost:9047) and log in with your admin credentials.

### From within the cluster

Other services connect to Dremio using:

```
http://dremio.query.svc.cluster.local:9047
```

JDBC/ODBC connections use port `31010`, Arrow Flight uses port `32010`.

## Connecting Nessie as a source

After Dremio is running, add Nessie as a catalog source via the UI.

### Step 1 — Add source

1. Click **Add Source** in the bottom-left corner
2. Select **Nessie** from the source list

### Step 2 — General tab

| Field | Value |
| --- | --- |
| Name | `nessie` |
| Nessie Endpoint URL | `http://nessie.catalog.svc.cluster.local:19120/api/v2` |
| Authentication | `None` |

### Step 3 — Storage tab

| Field | Value |
| --- | --- |
| AWS Root Path | `warehouse` |
| AWS Access Key | your MinIO access key |
| AWS Secret Key | your MinIO secret key |
| Encrypt Connection | `off` |

### Step 4 — Advanced Options

Add the following connection properties:

| Property | Value                                  |
| --- |----------------------------------------|
| `fs.s3a.endpoint` | `minio.storage.svc.cluster.local:9000` |
| `fs.s3a.path.style.access` | `true`                                 |
| `dremio.s3.compat` | `true`                                 |
| `fs.s3a.endpoint.region` | `eu-west-2`                            |

Click **Save**. Dremio will connect to Nessie and list available Iceberg tables.

### Step 5 — Verify

Expand the `nessie` source in the left panel. You should see the `main` branch and any registered namespaces (e.g. `bronze`, `silver`, `gold`).

Run a test query in the SQL Runner:

```sql
SELECT * FROM nessie.bronze.titanic LIMIT 10;
```

## Re-deploying

If you need to redeploy from scratch (e.g. after a cluster reset):

```bash
kubectl delete statefulset dremio-master-coordinator -n query
kubectl delete pvc dremio-storage-dremio-master-coordinator-0 -n query
kubectl apply -f dremio-credentials.sealed.secret.yaml
kubectl apply -f configmap.yaml
kubectl apply -f statefulset.yaml
kubectl apply -f service.yaml
```

> **Note:** Deleting the PVC wipes all Dremio metadata including sources, reflections, and user accounts. You will need to reconfigure sources after a fresh install.