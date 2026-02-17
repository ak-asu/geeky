#!/bin/bash
# Deploy Celery Beat scheduler as a Cloud Run Service (always-on, single instance).
set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:?Set GCP_PROJECT_ID}"
REGION="${GCP_REGION:-us-central1}"
SERVICE_NAME="geeky-beat"
SA_EMAIL="geeky-backend@${PROJECT_ID}.iam.gserviceaccount.com"
REGISTRY="${REGION}-docker.pkg.dev/${PROJECT_ID}/geeky-docker"
IMAGE="${REGISTRY}/${SERVICE_NAME}"

echo "=== Authenticating Docker with Artifact Registry ==="
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

echo "=== Building beat Docker image ==="
docker build -f Dockerfile.beat -t "${IMAGE}:latest" .

echo "=== Pushing to Artifact Registry ==="
docker push "${IMAGE}:latest"

echo "=== Deploying beat scheduler to Cloud Run ==="
gcloud run deploy "${SERVICE_NAME}" \
  --image "${IMAGE}:latest" \
  --platform managed \
  --region "${REGION}" \
  --no-allow-unauthenticated \
  --service-account "${SA_EMAIL}" \
  --set-env-vars "ENVIRONMENT=production,LOG_LEVEL=INFO" \
  --set-secrets "REDIS_URL=REDIS_URL:latest,CELERY_BROKER_URL=CELERY_BROKER_URL:latest" \
  --memory 256Mi \
  --cpu 1 \
  --min-instances 1 \
  --max-instances 1 \
  --timeout 3600 \
  --no-cpu-throttling

echo "=== Beat scheduler deployed ==="
