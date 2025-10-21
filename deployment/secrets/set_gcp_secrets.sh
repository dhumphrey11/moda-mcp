#!/usr/bin/env bash
# Create or update Google Secret Manager secrets with provided values.
# Usage:
#   export GCP_PROJECT_ID=... (or set with gcloud config set project ...)
#   export ALPHAVANTAGE_API_KEY=... COINGECKO_API_KEY=... COINAPI_API_KEY=... 
#   export COINDESK_API_KEY=... COINBASE_API_KEY=... COINBASE_SECRET=... POLYGON_API_KEY=...
#   bash deployment/secrets/set_gcp_secrets.sh
# Notes:
# - Requires gcloud CLI authenticated (gcloud auth login) and project set.
# - This script creates secrets (if missing) and adds a new version for each provided value.
# - It does not assign IAM access; bind access to Cloud Run service accounts per-service later.
set -euo pipefail

if ! command -v gcloud >/dev/null 2>&1; then
  echo "Error: gcloud CLI not found. Install Google Cloud SDK." >&2
  exit 1
fi

PROJECT_ID="${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || true)}"
if [[ -z "${PROJECT_ID}" || "${PROJECT_ID}" == "(unset)" ]]; then
  echo "Error: No project. Set GCP_PROJECT_ID or run: gcloud config set project <PROJECT_ID>" >&2
  exit 1
fi

echo "Using project: ${PROJECT_ID}"

gcloud services enable secretmanager.googleapis.com --project "${PROJECT_ID}" >/dev/null

create_if_missing() {
  local name="$1"
  if ! gcloud secrets describe "$name" --project "$PROJECT_ID" >/dev/null 2>&1; then
    gcloud secrets create "$name" --replication-policy="automatic" --project "$PROJECT_ID" >/dev/null
    echo "Created secret: $name"
  fi
}

add_version() {
  local name="$1"; local val="$2"
  if [[ -z "$val" ]]; then
    echo "Skipping $name (no value in env)"
    return 0
  fi
  printf "%s" "$val" | gcloud secrets versions add "$name" --data-file=- --project "$PROJECT_ID" >/dev/null
  echo "Added secret version: $name"
}

# Provider keys
for key in \
  ALPHAVANTAGE_API_KEY \
  COINGECKO_API_KEY \
  COINAPI_API_KEY \
  COINDESK_API_KEY \
  COINBASE_API_KEY \
  COINBASE_SECRET \
  POLYGON_API_KEY; do
  create_if_missing "$key"
  add_version "$key" "${!key:-}"
done

echo "Done setting Google Secret Manager secrets in ${PROJECT_ID}"
