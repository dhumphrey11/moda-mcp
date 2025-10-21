#!/usr/bin/env bash
# Verify service account permissions for Cloud Run deployment
# This checks the service account defined in GCP_SA_KEY secret

set -euo pipefail

echo "=== Service Account Permission Verification ==="
echo ""

# Check if we have a service account key file or need to extract from GitHub secret
SA_KEY_FILE="${1:-}"

if [[ -z "${SA_KEY_FILE}" ]]; then
  echo "📋 No service account key file provided."
  echo "   This script will help you verify the service account has the correct permissions."
  echo ""
  echo "To verify with the actual service account key used in GitHub Actions:"
  echo "   1. Temporarily save the GCP_SA_KEY secret to a file"
  echo "   2. Run: ./deployment/verify_service_account.sh /path/to/service-account-key.json"
  echo ""
  echo "For now, let's check what service accounts exist in your project..."
  echo ""
fi

PROJECT_ID="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "${PROJECT_ID}" || "${PROJECT_ID}" == "(unset)" ]]; then
  echo "❌ Error: No active GCP project set. Run: gcloud config set project <PROJECT_ID>"
  exit 1
fi

echo "📋 Project ID: ${PROJECT_ID}"
echo ""

# List all service accounts
echo "=== Service Accounts in Project ==="
gcloud iam service-accounts list --project="${PROJECT_ID}" --format="table(email,displayName)"
echo ""

# If a service account key is provided, verify it
if [[ -n "${SA_KEY_FILE}" && -f "${SA_KEY_FILE}" ]]; then
  echo "🔑 Extracting service account email from key file..."
  SA_EMAIL=$(jq -r '.client_email' "${SA_KEY_FILE}")
  echo "📧 Service Account: ${SA_EMAIL}"
  echo ""
  
  # Authenticate with this service account
  echo "🔐 Authenticating with service account..."
  gcloud auth activate-service-account --key-file="${SA_KEY_FILE}"
  echo "✅ Authenticated"
  echo ""
  
  # Run the main verification script
  echo "Running access verification with service account..."
  ./deployment/verify_gcp_access.sh "${SA_KEY_FILE}"
  
else
  # Show what roles should be assigned
  echo "=== Required Roles for Cloud Run Service Account ==="
  echo ""
  echo "The service account used by Cloud Run needs these roles:"
  echo "  1. roles/bigquery.dataEditor     - Write data to BigQuery"
  echo "  2. roles/secretmanager.secretAccessor - Read secrets"
  echo "  3. roles/logging.logWriter       - Write logs"
  echo ""
  echo "To assign roles to a service account:"
  echo '  SERVICE_ACCOUNT="your-service-account@PROJECT_ID.iam.gserviceaccount.com"'
  echo '  gcloud projects add-iam-policy-binding '"${PROJECT_ID}"' \'
  echo '    --member="serviceAccount:${SERVICE_ACCOUNT}" \'
  echo '    --role="roles/bigquery.dataEditor"'
  echo ""
  echo '  gcloud projects add-iam-policy-binding '"${PROJECT_ID}"' \'
  echo '    --member="serviceAccount:${SERVICE_ACCOUNT}" \'
  echo '    --role="roles/secretmanager.secretAccessor"'
  echo ""
  echo '  gcloud projects add-iam-policy-binding '"${PROJECT_ID}"' \'
  echo '    --member="serviceAccount:${SERVICE_ACCOUNT}" \'
  echo '    --role="roles/logging.logWriter"'
  echo ""
  
  # Check if there's a default compute service account
  DEFAULT_SA="${PROJECT_ID}@appspot.gserviceaccount.com"
  echo "=== Checking Default Compute Service Account Roles ==="
  echo "📧 Service Account: ${DEFAULT_SA}"
  echo ""
  
  if gcloud projects get-iam-policy "${PROJECT_ID}" \
    --flatten="bindings[].members" \
    --filter="bindings.members:serviceAccount:${DEFAULT_SA}" \
    --format="table(bindings.role)" 2>/dev/null | grep -q "roles/"; then
    
    echo "Current roles for ${DEFAULT_SA}:"
    gcloud projects get-iam-policy "${PROJECT_ID}" \
      --flatten="bindings[].members" \
      --filter="bindings.members:serviceAccount:${DEFAULT_SA}" \
      --format="table(bindings.role)"
  else
    echo "❌ No roles found for default service account"
  fi
  echo ""
  
  # Check if Cloud Run API is enabled
  echo "=== Checking Cloud Run API ==="
  if gcloud services list --enabled --filter="name:run.googleapis.com" --format="value(name)" | grep -q "run.googleapis.com"; then
    echo "✅ Cloud Run API is enabled"
  else
    echo "❌ Cloud Run API is NOT enabled"
    echo "   Enable it with: gcloud services enable run.googleapis.com"
  fi
  echo ""
fi

echo "=== Next Steps ==="
echo ""
echo "1. Ensure service account has required roles (see above)"
echo "2. Update Cloud Run deployment with service account:"
echo "   gcloud run deploy SERVICE_NAME --service-account=SERVICE_ACCOUNT_EMAIL"
echo ""
echo "3. For local development, set up application default credentials:"
echo "   gcloud auth application-default login"
echo ""
echo "4. Or use service account key for local development:"
echo "   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json"
echo ""
