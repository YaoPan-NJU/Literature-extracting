#!/usr/bin/env bash
set -u

cd /Users/panyao/Qoder/JJJ_Literature
export OPENCLAW_CONFIG_PATH="$PWD/openclaw.json"

exec bash scripts/launch_multi_extract.sh \
  --only-bailian \
  --mode multimodal \
  --preprocess-workers "${PREPROCESS_WORKERS:-1}" \
  "$@"
