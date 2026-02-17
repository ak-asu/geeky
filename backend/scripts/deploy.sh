#!/bin/bash
# Deploy FastAPI service to Google Cloud Run.
set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:?Set GCP_PROJECT_ID}"
REGION="${GCP_REGION:-us-central1}"
SERVICE_NAME="geeky-api"
SA_EMAIL="geeky-backend@${PROJECT_ID}.iam.gserviceaccount.com"
REGISTRY="${REGION}-docker.pkg.dev/${PROJECT_ID}/geeky-docker"
IMAGE="${REGISTRY}/${SERVICE_NAME}"

echo "=== Authenticating Docker with Artifact Registry ==="
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

echo "=== Building Docker image ==="
docker build -t "${IMAGE}:latest" .

echo "=== Pushing to Artifact Registry ==="
docker push "${IMAGE}:latest"

echo "=== Deploying to Cloud Run ==="
gcloud run deploy "${SERVICE_NAME}" \
  --image "${IMAGE}:latest" \
  --platform managed \
  --region "${REGION}" \
  --allow-unauthenticated \
  --service-account "${SA_EMAIL}" \
  --set-env-vars "ENVIRONMENT=production,LOG_LEVEL=WARNING,FIREBASE_PROJECT_ID=${PROJECT_ID}" \
  --set-secrets "GEMINI_API_KEY=GEMINI_API_KEY:latest,REDIS_URL=REDIS_URL:latest,CELERY_BROKER_URL=CELERY_BROKER_URL:latest,CELERY_RESULT_BACKEND=CELERY_RESULT_BACKEND:latest" \
  --memory 512Mi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 10 \
  --timeout 300 \
  --port 8000

echo "=== Deployment complete ==="
gcloud run services describe "${SERVICE_NAME}" --region "${REGION}" --format 'value(status.url)'
