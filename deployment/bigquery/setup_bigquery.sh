#!/usr/bin/env bash
# Create the BigQuery dataset and tables for the moda-mcp project using gcloud and bq CLI.
# - Creates dataset: moda_mcp (in your default GCP project)
# - Creates tables with partitioning and clustering as specified
# - Grants OWNER access only to the current gcloud account
# - Prints verification listings at the end

set -euo pipefail

# Preflight: ensure required CLIs are available
if ! command -v gcloud >/dev/null 2>&1; then
  echo "Error: gcloud CLI not found. Install Google Cloud SDK and ensure gcloud is on your PATH." >&2
  echo "Docs: https://cloud.google.com/sdk/docs/install" >&2
  exit 1
fi

if ! command -v bq >/dev/null 2>&1; then
  echo "Error: bq CLI not found on PATH." >&2
  echo "The BigQuery bq tool is part of the Google Cloud SDK. If you installed via Homebrew, make sure you source the SDK path script:" >&2
  echo "  # zsh" >&2
  echo "  source \"$(brew --prefix 2>/dev/null)/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc\" 2>/dev/null || true" >&2
  echo "Or re-open your terminal after installing google-cloud-sdk." >&2
  echo "Docs: https://cloud.google.com/bigquery/docs/bq-command-line-tool" >&2
  exit 1
fi

# Configuration
PROJECT_ID="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "${PROJECT_ID}" || "${PROJECT_ID}" == "(unset)" ]]; then
  echo "Error: No active GCP project set. Run: gcloud config set project <PROJECT_ID>" >&2
  exit 1
fi

# BigQuery dataset location: set BQ_LOCATION env var to override (e.g., US, EU)
LOCATION="${BQ_LOCATION:-US}"
DATASET="moda_mcp"
ACCOUNT="$(gcloud config get-value account 2>/dev/null || true)"

if [[ -z "${ACCOUNT}" || "${ACCOUNT}" == "(unset)" ]]; then
  echo "Error: No active gcloud account found. Run: gcloud auth login" >&2
  exit 1
fi

echo "Using project:    ${PROJECT_ID}"
echo "Dataset:          ${DATASET} (location: ${LOCATION})"
echo "Owner account:    ${ACCOUNT}"

echo "Ensuring BigQuery API is enabled..."
gcloud services enable bigquery.googleapis.com --project "${PROJECT_ID}" >/dev/null

# Create dataset if it does not exist
if ! bq show -d "${PROJECT_ID}:${DATASET}" >/dev/null 2>&1; then
  echo "Creating dataset ${PROJECT_ID}:${DATASET} in ${LOCATION}..."
  bq --location="${LOCATION}" mk --dataset "${PROJECT_ID}:${DATASET}" || true
else
  echo "Dataset ${PROJECT_ID}:${DATASET} already exists."
fi

# Set dataset access: OWNER = current account only
# Note: This removes existing dataset access entries. Ensure this is what you want.
ACCESS_JSON_FILE="$(mktemp)"
cat >"${ACCESS_JSON_FILE}" <<EOF
[
  {"role": "OWNER", "userByEmail": "${ACCOUNT}"}
]
EOF

echo "Configuring dataset access (OWNER: ${ACCOUNT})..."
# Try to apply access list; if unsupported in this bq build, continue with a warning.
if bq update --access "$(cat "${ACCESS_JSON_FILE}")" "${PROJECT_ID}:${DATASET}" >/dev/null 2>&1; then
  echo "Dataset access updated to OWNER=${ACCOUNT}."
else
  echo "Warning: Unable to modify dataset access via 'bq update --access' on this environment. Skipping ACL change."
fi
rm -f "${ACCESS_JSON_FILE}"

echo "Creating/Updating tables (HOURLY partitioning)..."

# Helper to check if a table exists
has_table() {
  local tbl="$1" # format: project:dataset.table
  bq show -q "$tbl" >/dev/null 2>&1
}

# raw_ohlcv (partitioned by timestamp (HOURLY), clustered by symbol)
RAW_TABLE="${PROJECT_ID}:${DATASET}.raw_ohlcv"
if has_table "${RAW_TABLE}"; then
  if [[ "${FORCE_RECREATE:-}" == "1" || "${FORCE_RECREATE:-}" == "true" ]]; then
    echo "Recreating table: ${RAW_TABLE} with HOURLY partitioning (dropping existing table)"
    bq rm -f -t "${RAW_TABLE}" || true
  else
    echo "Table exists: ${RAW_TABLE} (set FORCE_RECREATE=1 to drop and recreate with HOURLY partitioning)"
  fi
fi
if ! has_table "${RAW_TABLE}"; then
  echo "Creating table: ${RAW_TABLE} (partition=HOUR by timestamp, cluster=symbol)"
  bq mk --table \
    --time_partitioning_type=HOUR \
    --time_partitioning_field=timestamp \
    --clustering_fields=symbol \
    "${RAW_TABLE}" \
    timestamp:TIMESTAMP,symbol:STRING,open:FLOAT,high:FLOAT,low:FLOAT,close:FLOAT,volume:FLOAT
fi

# features (partitioned by timestamp HOURLY)
FEATURES_TABLE="${PROJECT_ID}:${DATASET}.features"
if has_table "${FEATURES_TABLE}"; then
  if [[ "${FORCE_RECREATE:-}" == "1" || "${FORCE_RECREATE:-}" == "true" ]]; then
    echo "Recreating table: ${FEATURES_TABLE} with HOURLY partitioning (dropping existing table)"
    bq rm -f -t "${FEATURES_TABLE}" || true
  else
    echo "Table exists: ${FEATURES_TABLE} (set FORCE_RECREATE=1 to drop and recreate with HOURLY partitioning)"
  fi
fi
if ! has_table "${FEATURES_TABLE}"; then
  echo "Creating table: ${FEATURES_TABLE} (partition=HOUR by timestamp)"
  bq mk --table \
    --time_partitioning_type=HOUR \
    --time_partitioning_field=timestamp \
    "${FEATURES_TABLE}" \
    timestamp:TIMESTAMP,symbol:STRING,feature_name:STRING,feature_value:FLOAT
fi

# signals (partitioned by timestamp HOURLY)
SIGNALS_TABLE="${PROJECT_ID}:${DATASET}.signals"
if has_table "${SIGNALS_TABLE}"; then
  if [[ "${FORCE_RECREATE:-}" == "1" || "${FORCE_RECREATE:-}" == "true" ]]; then
    echo "Recreating table: ${SIGNALS_TABLE} with HOURLY partitioning (dropping existing table)"
    bq rm -f -t "${SIGNALS_TABLE}" || true
  else
    echo "Table exists: ${SIGNALS_TABLE} (set FORCE_RECREATE=1 to drop and recreate with HOURLY partitioning)"
  fi
fi
if ! has_table "${SIGNALS_TABLE}"; then
  echo "Creating table: ${SIGNALS_TABLE} (partition=HOUR by timestamp)"
  bq mk --table \
    --time_partitioning_type=HOUR \
    --time_partitioning_field=timestamp \
    "${SIGNALS_TABLE}" \
    timestamp:TIMESTAMP,symbol:STRING,signal_type:STRING,signal_strength:FLOAT
fi

# paper_trading_pnl (partitioned by timestamp HOURLY)
PNL_TABLE="${PROJECT_ID}:${DATASET}.paper_trading_pnl"
if has_table "${PNL_TABLE}"; then
  if [[ "${FORCE_RECREATE:-}" == "1" || "${FORCE_RECREATE:-}" == "true" ]]; then
    echo "Recreating table: ${PNL_TABLE} with HOURLY partitioning (dropping existing table)"
    bq rm -f -t "${PNL_TABLE}" || true
  else
    echo "Table exists: ${PNL_TABLE} (set FORCE_RECREATE=1 to drop and recreate with HOURLY partitioning)"
  fi
fi
if ! has_table "${PNL_TABLE}"; then
  echo "Creating table: ${PNL_TABLE} (partition=HOUR by timestamp)"
  bq mk --table \
    --time_partitioning_type=HOUR \
    --time_partitioning_field=timestamp \
    "${PNL_TABLE}" \
    timestamp:TIMESTAMP,symbol:STRING,position_size:FLOAT,entry_price:FLOAT,exit_price:FLOAT,pnl:FLOAT
fi

# Verification
echo "\nVerification: list dataset and tables"
echo "Datasets:"
bq ls -d --project_id="${PROJECT_ID}"

echo "\nTables in ${PROJECT_ID}:${DATASET}:"
bq ls "${PROJECT_ID}:${DATASET}"

echo "\nSample table schema (raw_ohlcv):"
bq show --format=prettyjson "${RAW_TABLE}" | sed -n '1,120p'

echo "\nDone."
