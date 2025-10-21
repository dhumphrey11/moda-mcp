#!/usr/bin/env bash
set -euo pipefail

# Minimal Cloud Run deploy script for a single service.
# Usage:
#   PROJECT_ID=your-gcp-project REGION=us-central1 SERVICE_NAME=features SERVICE_PATH=./features ./deployment/cloud_run/deploy.sh

: "${PROJECT_ID:?Set PROJECT_ID}"
: "${REGION:?Set REGION}"
: "${SERVICE_NAME:?Set SERVICE_NAME}"
: "${SERVICE_PATH:?Set SERVICE_PATH}"

IMAGE="gcr.io/${PROJECT_ID}/${SERVICE_NAME}:latest"

echo "Building ${IMAGE} from ${SERVICE_PATH}..."
gcloud builds submit "${SERVICE_PATH}" --tag "${IMAGE}"

echo "Deploying ${SERVICE_NAME} to Cloud Run in ${REGION}..."
gcloud run deploy "${SERVICE_NAME}" \
  --image "${IMAGE}" \
  --region "${REGION}" \
  --platform managed \
  --allow-unauthenticated \
  --port 8000

echo "Done. Service URL:"
gcloud run services describe "${SERVICE_NAME}" --region "${REGION}" --format='value(status.url)'
