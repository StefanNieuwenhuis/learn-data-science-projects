#!/bin/bash

# Port-forward MinIO and Nessie in parallel
echo "Starting port-forwards..."
echo "  MinIO API:      http://localhost:9000"
echo "  MinIO Console:  http://localhost:9001"
echo "  Nessie API:     http://localhost:19120"
echo "  Dremio Console: http://localhost:9047"
echo ""
echo "Press Ctrl+C to stop all."

kubectl port-forward svc/minio 9000:9000 9001:9001 -n storage &
MINIO_PID=$!

kubectl port-forward svc/nessie 19120:19120 -n catalog &
NESSIE_PID=$!

kubectl port-forward svc/dremio 9047:9047 -n query &
DREMIO_PID=$!

trap "kill $MINIO_PID $NESSIE_PID $DREMIO_PID 2>/dev/null; exit" INT TERM

wait
