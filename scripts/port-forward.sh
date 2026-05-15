#!/bin/bash

# Port-forward MinIO API and Console
echo "Starting MinIO port-forwards..."
echo "  API:     http://localhost:9000"
echo "  Console: http://localhost:9001"
echo ""
echo "Press Ctrl+C to stop."

kubectl port-forward svc/minio 9000:9000 9001:9001 -n storage