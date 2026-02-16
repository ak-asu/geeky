#!/bin/bash
# Deploy Celery worker as a Cloud Run Job
set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:?Set GCP_PROJECT_ID}"
REGION="${GCP_REGION:-us-central1}"
JOB_NAME="geeky-worker"
IMAGE="gcr.io/${PROJECT_ID}/${JOB_NAME}"

echo "=== Building worker Docker image ==="
docker build -f Dockerfile.worker -t "${IMAGE}" .

echo "=== Pushing to Container Registry ==="
docker push "${IMAGE}"

echo "=== Creating/Updating Cloud Run Job ==="
gcloud run jobs replace - <<EOF
apiVersion: run.googleapis.com/v1
kind: Job
metadata:
  name: ${JOB_NAME}
spec:
  template:
    spec:
      template:
        spec:
          containers:
            - image: ${IMAGE}
              resources:
                limits:
                  memory: 1Gi
                  cpu: '1'
          timeoutSeconds: 3600
          maxRetries: 3
EOF

echo "=== Worker job deployed ==="
