# Local Development Environment Setup

This guide helps you set up your local development environment to access GCP resources (BigQuery and Secret Manager).

## Prerequisites

- Google Cloud SDK installed (`gcloud` CLI)
- Python 3.11+
- Service account key file (optional, for programmatic access)

## Method 1: User Account Authentication (Recommended for Development)

This method uses your personal Google account credentials:

```bash
# Authenticate with your Google account
gcloud auth application-default login

# Set your project
gcloud config set project moda-mcp

# Verify authentication
gcloud auth application-default print-access-token
```

### Testing Access

```bash
# Test BigQuery access
bq query --use_legacy_sql=false 'SELECT 1 as test'

# Test Secret Manager access
gcloud secrets list --limit=5

# Run the verification script
./deployment/verify_gcp_access.sh
```

## Method 2: Service Account Authentication (For Production-Like Testing)

If you need to test with the same credentials used in production:

```bash
# 1. Download the service account key (if you don't have it)
#    Navigate to: https://console.cloud.google.com/iam-admin/serviceaccounts?project=moda-mcp
#    Find: github-deployer@moda-mcp.iam.gserviceaccount.com
#    Create and download a key (JSON format)

# 2. Set the environment variable
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"

# 3. Verify authentication
gcloud auth activate-service-account --key-file="${GOOGLE_APPLICATION_CREDENTIALS}"

# 4. Run verification
./deployment/verify_gcp_access.sh "${GOOGLE_APPLICATION_CREDENTIALS}"
```

## Environment Variables for Local Development

Create a `.env` file in the root of your project (this file is gitignored):

```bash
# GCP Configuration
GCP_PROJECT_ID=moda-mcp
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json  # Optional

# BigQuery
BQ_DATASET=moda_mcp

# API Keys (will be fetched from Secret Manager if not set)
# These are optional - services will fetch from Secret Manager if not provided
# COINBASE_API_KEY=
# COINBASE_SECRET=
# COINGECKO_API_KEY=
# POLYGON_API_KEY=
# COINAPI_API_KEY=
# ALPHAVANTAGE_API_KEY=
# COINDESK_API_KEY=
```

## Python Code Example: Accessing Secrets

```python
from google.cloud import secretmanager
import os

def get_secret(secret_name: str, project_id: str = None) -> str:
    """
    Fetch a secret from Google Secret Manager.
    
    Args:
        secret_name: Name of the secret (e.g., 'COINBASE_API_KEY')
        project_id: GCP project ID (defaults to env var or metadata)
    
    Returns:
        Secret value as string
    """
    if project_id is None:
        project_id = os.environ.get('GCP_PROJECT_ID', 'moda-mcp')
    
    client = secretmanager.SecretManagerServiceClient()
    secret_path = f"projects/{project_id}/secrets/{secret_name}/versions/latest"
    
    response = client.access_secret_version(request={"name": secret_path})
    return response.payload.data.decode('UTF-8')

# Usage in your service
try:
    api_key = os.environ.get('COINBASE_API_KEY') or get_secret('COINBASE_API_KEY')
except Exception as e:
    print(f"Warning: Could not fetch secret: {e}")
    api_key = None
```

## Python Code Example: Writing to BigQuery

```python
from google.cloud import bigquery
import os
from datetime import datetime

def write_to_bigquery(table_name: str, rows: list[dict], project_id: str = None):
    """
    Write rows to BigQuery.
    
    Args:
        table_name: Table name (e.g., 'raw_ohlcv')
        rows: List of dictionaries with data
        project_id: GCP project ID
    """
    if project_id is None:
        project_id = os.environ.get('GCP_PROJECT_ID', 'moda-mcp')
    
    client = bigquery.Client(project=project_id)
    dataset_id = os.environ.get('BQ_DATASET', 'moda_mcp')
    table_ref = f"{project_id}.{dataset_id}.{table_name}"
    
    errors = client.insert_rows_json(table_ref, rows)
    
    if errors:
        raise Exception(f"BigQuery insert errors: {errors}")
    
    print(f"Successfully inserted {len(rows)} rows into {table_ref}")

# Usage example
data = [
    {
        "timestamp": datetime.utcnow().isoformat(),
        "symbol": "BTC-USD",
        "open": 50000.0,
        "high": 51000.0,
        "low": 49500.0,
        "close": 50500.0,
        "volume": 1000.0
    }
]

write_to_bigquery('raw_ohlcv', data)
```

## Running Services Locally

Each service can be run independently:

```bash
# Navigate to a service directory
cd ingestion/coinbase

# Activate virtual environment
source ../../venv/bin/activate

# Set environment variables
export GCP_PROJECT_ID=moda-mcp
export BQ_DATASET=moda_mcp

# Run the service
python -m uvicorn main:app --reload --port 8000
```

## Troubleshooting

### "Permission Denied" errors

```bash
# Check which account is active
gcloud auth list

# Check project configuration
gcloud config list

# Re-authenticate
gcloud auth application-default login
```

### Cannot access secrets

```bash
# Verify Secret Manager API is enabled
gcloud services enable secretmanager.googleapis.com

# List available secrets
gcloud secrets list

# Test reading a specific secret
gcloud secrets versions access latest --secret=COINBASE_API_KEY
```

### Cannot write to BigQuery

```bash
# Verify BigQuery API is enabled
gcloud services enable bigquery.googleapis.com

# Check dataset exists
bq ls moda-mcp:moda_mcp

# Run the verification script
./deployment/verify_gcp_access.sh
```

### Rate limiting or quota errors

Check your GCP quotas:
- BigQuery: https://console.cloud.google.com/apis/api/bigquery.googleapis.com/quotas?project=moda-mcp
- Secret Manager: https://console.cloud.google.com/apis/api/secretmanager.googleapis.com/quotas?project=moda-mcp

## Additional Resources

- [Google Cloud Python Client Libraries](https://cloud.google.com/python/docs/reference)
- [BigQuery Python Client](https://cloud.google.com/python/docs/reference/bigquery/latest)
- [Secret Manager Python Client](https://cloud.google.com/python/docs/reference/secretmanager/latest)
- [Application Default Credentials](https://cloud.google.com/docs/authentication/application-default-credentials)
