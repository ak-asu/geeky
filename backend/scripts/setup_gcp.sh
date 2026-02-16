#!/bin/bash
# One-time GCP project setup for Geeky backend
set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:?Set GCP_PROJECT_ID}"
REGION="${GCP_REGION:-us-central1}"

echo "=== Setting project ==="
gcloud config set project "${PROJECT_ID}"

echo "=== Enabling required APIs ==="
gcloud services enable \
  run.googleapis.com \
  firestore.googleapis.com \
  secretmanager.googleapis.com \
  cloudbuild.googleapis.com \
  containerregistry.googleapis.com \
  firebase.googleapis.com

echo "=== Creating Firestore database (Native mode) ==="
gcloud firestore databases create --location="${REGION}" 2>/dev/null || echo "Firestore already exists"

echo "=== Creating secrets in Secret Manager ==="
echo "Note: You need to set these secret values manually:"
echo "  gcloud secrets create GEMINI_API_KEY --replication-policy=automatic"
echo "  echo -n 'your-key' | gcloud secrets versions add GEMINI_API_KEY --data-file=-"
echo ""
echo "  gcloud secrets create REDIS_URL --replication-policy=automatic"
echo "  echo -n 'redis://...' | gcloud secrets versions add REDIS_URL --data-file=-"

echo "=== Setup complete ==="
echo "Next steps:"
echo "1. Set secret values (see above)"
echo "2. Run ./scripts/deploy.sh to deploy the API"
echo "3. Run ./scripts/deploy_worker.sh to deploy the worker"
