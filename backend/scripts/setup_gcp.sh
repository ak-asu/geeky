#!/bin/bash
# One-time GCP project setup for Geeky backend.
# Run once to bootstrap the GCP environment.
set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:?Set GCP_PROJECT_ID}"
REGION="${GCP_REGION:-us-central1}"
SA_NAME="geeky-backend"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "=== Setting project ==="
gcloud config set project "${PROJECT_ID}"

echo "=== Enabling required APIs ==="
gcloud services enable \
  run.googleapis.com \
  firestore.googleapis.com \
  secretmanager.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  firebase.googleapis.com \
  iam.googleapis.com

echo "=== Creating Artifact Registry Docker repo ==="
gcloud artifacts repositories create geeky-docker \
  --repository-format=docker \
  --location="${REGION}" \
  --description="Geeky backend Docker images" \
  2>/dev/null || echo "Artifact Registry repo already exists"

echo "=== Creating Firestore database (Native mode) ==="
gcloud firestore databases create --location="${REGION}" 2>/dev/null || echo "Firestore already exists"

echo "=== Creating service account ==="
gcloud iam service-accounts create "${SA_NAME}" \
  --display-name="Geeky Backend Service Account" \
  2>/dev/null || echo "Service account already exists"

echo "=== Granting IAM roles ==="
for ROLE in \
  roles/datastore.user \
  roles/secretmanager.secretAccessor \
  roles/run.invoker \
  roles/logging.logWriter \
  roles/monitoring.metricWriter; do
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="${ROLE}" \
    --quiet
done

echo "=== Creating secrets in Secret Manager ==="
SECRETS=(GEMINI_API_KEY REDIS_URL CELERY_BROKER_URL CELERY_RESULT_BACKEND)
for SECRET in "${SECRETS[@]}"; do
  gcloud secrets create "${SECRET}" --replication-policy=automatic \
    2>/dev/null || echo "Secret ${SECRET} already exists"
done

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Set secret values:"
for SECRET in "${SECRETS[@]}"; do
  echo "     echo -n 'value' | gcloud secrets versions add ${SECRET} --data-file=-"
done
echo ""
echo "  2. Deploy services:"
echo "     ./scripts/deploy.sh        # API"
echo "     ./scripts/deploy_worker.sh # Celery worker"
echo "     ./scripts/deploy_beat.sh   # Celery beat scheduler"
