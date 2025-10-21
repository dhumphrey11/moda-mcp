#!/usr/bin/env bash
# Verify GCP access for service accounts and secrets
# Usage: ./verify_gcp_access.sh [service_account_key.json]

set -euo pipefail

echo "=== GCP Access Verification Script ==="
echo ""

# Check if gcloud is installed
if ! command -v gcloud >/dev/null 2>&1; then
  echo "❌ Error: gcloud CLI not found. Install Google Cloud SDK first."
  exit 1
fi

# Get current project
PROJECT_ID="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "${PROJECT_ID}" || "${PROJECT_ID}" == "(unset)" ]]; then
  echo "❌ Error: No active GCP project set. Run: gcloud config set project <PROJECT_ID>"
  exit 1
fi

echo "📋 Project ID: ${PROJECT_ID}"
echo ""

# If a service account key is provided, authenticate with it
if [[ $# -gt 0 ]]; then
  SA_KEY_FILE="$1"
  if [[ -f "${SA_KEY_FILE}" ]]; then
    echo "🔑 Authenticating with service account key: ${SA_KEY_FILE}"
    gcloud auth activate-service-account --key-file="${SA_KEY_FILE}"
    echo "✅ Service account authenticated"
  else
    echo "❌ Service account key file not found: ${SA_KEY_FILE}"
    exit 1
  fi
fi

ACCOUNT="$(gcloud config get-value account 2>/dev/null || true)"
echo "👤 Active account: ${ACCOUNT}"
echo ""

# Check BigQuery API is enabled
echo "=== Checking BigQuery API ==="
if gcloud services list --enabled --filter="name:bigquery.googleapis.com" --format="value(name)" | grep -q "bigquery.googleapis.com"; then
  echo "✅ BigQuery API is enabled"
else
  echo "❌ BigQuery API is NOT enabled"
  echo "   Enable it with: gcloud services enable bigquery.googleapis.com"
fi
echo ""

# Check Secret Manager API is enabled
echo "=== Checking Secret Manager API ==="
if gcloud services list --enabled --filter="name:secretmanager.googleapis.com" --format="value(name)" | grep -q "secretmanager.googleapis.com"; then
  echo "✅ Secret Manager API is enabled"
else
  echo "❌ Secret Manager API is NOT enabled"
  echo "   Enable it with: gcloud services enable secretmanager.googleapis.com"
fi
echo ""

# Test BigQuery write access
echo "=== Testing BigQuery Write Access ==="
DATASET="moda_mcp"
TEST_TABLE="${PROJECT_ID}:${DATASET}.access_test_$(date +%s)"

# Check if dataset exists
if bq show -d "${PROJECT_ID}:${DATASET}" >/dev/null 2>&1; then
  echo "✅ Dataset ${DATASET} exists"
  
  # Try to create a test table
  echo "🧪 Testing write access by creating a test table..."
  if bq mk --table "${TEST_TABLE}" "test_col:STRING" >/dev/null 2>&1; then
    echo "✅ Successfully created test table: ${TEST_TABLE}"
    
    # Try to insert data
    echo "🧪 Testing data insertion..."
    TEMP_JSON=$(mktemp)
    echo '{"test_col": "test_value"}' > "${TEMP_JSON}"
    if bq insert "${TEST_TABLE}" "${TEMP_JSON}" >/dev/null 2>&1; then
      echo "✅ Successfully inserted test data"
    else
      echo "❌ Failed to insert test data"
    fi
    rm -f "${TEMP_JSON}"
    
    # Clean up test table
    echo "🧹 Cleaning up test table..."
    bq rm -f -t "${TEST_TABLE}" >/dev/null 2>&1 || true
    echo "✅ Test table removed"
  else
    echo "❌ Failed to create test table - insufficient permissions"
    echo "   Required role: bigquery.dataEditor or bigquery.admin"
  fi
else
  echo "❌ Dataset ${DATASET} does not exist"
  echo "   Run: deployment/bigquery/setup_bigquery.sh"
fi
echo ""

# Check Secret Manager access
echo "=== Testing Secret Manager Access ==="
echo "📋 Listing secrets in project..."
if gcloud secrets list --project="${PROJECT_ID}" --limit=5 >/dev/null 2>&1; then
  SECRET_COUNT=$(gcloud secrets list --project="${PROJECT_ID}" --format="value(name)" | wc -l)
  echo "✅ Can list secrets (found ${SECRET_COUNT} secrets)"
  
  # List first 5 secrets
  echo "📝 Sample secrets:"
  gcloud secrets list --project="${PROJECT_ID}" --limit=5 --format="table(name,createTime)"
  
  # Test reading a secret if any exist
  FIRST_SECRET=$(gcloud secrets list --project="${PROJECT_ID}" --limit=1 --format="value(name)" 2>/dev/null || true)
  if [[ -n "${FIRST_SECRET}" ]]; then
    echo ""
    echo "🧪 Testing read access to secret: ${FIRST_SECRET}"
    if gcloud secrets versions access latest --secret="${FIRST_SECRET}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
      echo "✅ Successfully read secret value"
    else
      echo "❌ Failed to read secret value"
      echo "   Required role: secretmanager.secretAccessor"
    fi
  fi
else
  echo "❌ Failed to list secrets"
  echo "   Required role: secretmanager.viewer or secretmanager.admin"
fi
echo ""

# Check IAM roles for the current account
echo "=== IAM Roles for ${ACCOUNT} ==="
echo "📋 Fetching IAM policy..."
gcloud projects get-iam-policy "${PROJECT_ID}" \
  --flatten="bindings[].members" \
  --filter="bindings.members:${ACCOUNT}" \
  --format="table(bindings.role)" | grep -E "roles/(bigquery|secretmanager)" || echo "No BigQuery or Secret Manager roles found"
echo ""

# Summary
echo "=== Verification Summary ==="
echo "✅ Checks completed. Review the results above."
echo ""
echo "💡 For Cloud Run microservices:"
echo "   1. Ensure the service account has roles:"
echo "      - roles/bigquery.dataEditor (for writing data)"
echo "      - roles/secretmanager.secretAccessor (for reading secrets)"
echo "   2. Set the service account in Cloud Run deployment:"
echo "      --service-account=<service-account-email>"
echo ""
echo "💡 For local development:"
echo "   1. Use: gcloud auth application-default login"
echo "   2. Or set: export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json"
echo ""
