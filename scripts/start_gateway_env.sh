#!/usr/bin/env bash
# Start OpenClaw Gateway after loading a local .env file if it exists.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

load_dotenv() {
  local env_file="$1"
  local line key value
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "$line" || "$line" == \#* || "$line" != *=* ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    export "$key=$value"
  done < "$env_file"
}

if [[ -f ".env" ]]; then
  load_dotenv ".env"
fi

export OPENCLAW_CONFIG_PATH="$REPO_DIR/openclaw.json"

missing=()
for var_name in BAILIAN_CODING_PLAN_API_KEY MIMO_API_KEY; do
  var_value="${!var_name:-}"
  if [[ -z "$var_value" || "$var_value" == your_*_api_key_here ]]; then
    missing+=("$var_name")
  fi
done

if [[ "${#missing[@]}" -gt 0 ]]; then
  echo "ERROR: Missing required environment variable(s): ${missing[*]}"
  echo "Set them with: export BAILIAN_CODING_PLAN_API_KEY=\"your_key\" and export MIMO_API_KEY=\"your_key\""
  echo "Or create: $REPO_DIR/.env"
  exit 2
fi

exec openclaw gateway --force
