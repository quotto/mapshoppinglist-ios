#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "warning: Missing output directory for generate-secrets-json.sh" >&2
  exit 0
fi

OUTPUT_DIR="$1"
CONFIG_PATH="${OUTPUT_DIR}/AppSecrets.json"
mkdir -p "$OUTPUT_DIR"

echo "${GOOGLE_MAPS_API_KEY}"
API_KEY="${GOOGLE_MAPS_API_KEY:-}"

if [[ -z "$API_KEY" ]]; then
  cat > "$CONFIG_PATH" <<'JSON'
{
  "googleMaps": {}
}
JSON
  echo "warning: GOOGLE_MAPS_API_KEY is not set. Generated empty AppSecrets.json" >&2
else
  cat > "$CONFIG_PATH" <<JSON
{
  "googleMaps": {
    "apiKey": "${API_KEY}"
  }
}
JSON
fi
