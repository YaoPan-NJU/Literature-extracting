#!/usr/bin/env bash
# Clean bulky per-run extraction artifacts after results have been merged.

set -u

REMOVE_LOGS=0
RUN_DIRS=()

usage() {
  cat <<'USAGE'
Usage: scripts/cleanup_extraction_artifacts.sh --run-dir DIR [--logs]
       scripts/cleanup_extraction_artifacts.sh --all-old [--keep-run-id ID] [--logs]

Removes prompts/raw/text under run directories. With --logs, also removes
per-PDF hash logs while keeping launcher/worker summary logs.
USAGE
}

KEEP_RUN_ID=""
ALL_OLD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir) RUN_DIRS+=("${2:-}"); shift 2 ;;
    --all-old) ALL_OLD=1; shift ;;
    --keep-run-id) KEEP_RUN_ID="${2:-}"; shift 2 ;;
    --logs) REMOVE_LOGS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown: $1" >&2; exit 2 ;;
  esac
done

if [[ "$ALL_OLD" -eq 1 ]]; then
  for d in /tmp/openclaw/litextract_runs/*; do
    [[ -d "$d" ]] || continue
    [[ -n "$KEEP_RUN_ID" && "$(basename "$d")" == "$KEEP_RUN_ID" ]] && continue
    RUN_DIRS+=("$d")
  done
fi

if [[ "${#RUN_DIRS[@]}" -eq 0 ]]; then
  usage >&2
  exit 2
fi

is_run_active() {
  local run_dir="$1"
  ps -axo command= 2>/dev/null | grep -F "$run_dir" | grep -F "single_worker_extract.sh" >/dev/null
}

for run_dir in "${RUN_DIRS[@]}"; do
  [[ -n "$run_dir" && -d "$run_dir" ]] || continue
  if [[ ! -d "$run_dir/manifests" ]]; then
    echo "skip: $run_dir (no manifests)"
    continue
  fi
  if is_run_active "$run_dir"; then
    echo "skip: $run_dir (active worker process)"
    continue
  fi

  echo "clean: $run_dir"
  rm -rf "$run_dir/prompts" "$run_dir/raw" "$run_dir/text"
  mkdir -p "$run_dir/prompts" "$run_dir/raw" "$run_dir/text"

  if [[ "$REMOVE_LOGS" -eq 1 && -d "$run_dir/logs" ]]; then
    find "$run_dir/logs" -type f -name '*.log' \
      ! -name 'worker_*.log' \
      ! -name 'launch*.log' \
      ! -name 'run_*.log' \
      -delete
  fi
done
