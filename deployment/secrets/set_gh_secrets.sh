#!/usr/bin/env bash
# Set GitHub Actions repository secrets for moda-mcp.
# Usage:
#   export GCP_PROJECT_ID=... GCP_REGION=... \
#          ALPHAVANTAGE_API_KEY=... COINGECKO_API_KEY=... COINAPI_API_KEY=... \
#          COINDESK_API_KEY=... COINBASE_API_KEY=... COINBASE_SECRET=... POLYGON_API_KEY=... ; \
#   bash deployment/secrets/set_gh_secrets.sh
# Notes:
# - Requires GitHub CLI (gh) authenticated (gh auth login)
# - This script reads secret values from environment variables and does not echo them.
set -euo pipefail

REPO_SLUG=$(git config --get remote.origin.url | sed -E "s#(git@|https://)github.com[:/](.+)\.git#\2#")
if ! gh repo view "$REPO_SLUG" >/dev/null 2>&1; then
  echo "Error: gh CLI is not authenticated for $REPO_SLUG. Run: gh auth login" >&2
  exit 1
fi

put_secret() {
  local name="$1"
  local val="${!1:-}"
  if [[ -z "$val" ]]; then
    echo "Skipping $name (no value in env)"
    return 0
  fi
  printf "%s" "$val" | gh secret set "$name" --app actions --repo "$REPO_SLUG" >/dev/null
  echo "Set secret: $name"
}

# Required for CI/CD workflow
put_secret GCP_PROJECT_ID
put_secret GCP_REGION

# Provider keys
put_secret ALPHAVANTAGE_API_KEY
put_secret COINGECKO_API_KEY
put_secret COINAPI_API_KEY
put_secret COINDESK_API_KEY
put_secret COINBASE_API_KEY
put_secret COINBASE_SECRET
put_secret POLYGON_API_KEY

echo "Done setting GitHub secrets for $REPO_SLUG"
