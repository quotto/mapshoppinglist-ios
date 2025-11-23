#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "warning: Missing output directory for generate-secrets-json.sh" >&2
  exit 0
fi

OUTPUT_DIR="$1"
CONFIG_PATH="${OUTPUT_DIR}/AppSecrets.json"
mkdir -p "$OUTPUT_DIR"

API_KEY="${GOOGLE_MAPS_API_KEY:-}"

if [[ -z "$API_KEY" ]]; then
  cat > "$CONFIG_PATH" <<'JSON'
{
  "googleMaps": {}
}
JSON
  echo "warning: GOOGLE_MAPS_API_KEY is not set. Generated empty AppSecrets.json" >&2
else
  python3 - "$CONFIG_PATH" "$API_KEY" <<'PY'
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
api_key = sys.argv[2]
payload = {"googleMaps": {"apiKey": api_key}}
config_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
PY
fi
