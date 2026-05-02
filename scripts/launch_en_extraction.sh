#!/usr/bin/env bash
# Compatibility wrapper. Use launch_multi_extract.sh for active extraction runs.

set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "scripts/launch_en_extraction.sh is deprecated; forwarding to scripts/launch_multi_extract.sh" >&2
exec bash "$REPO_DIR/scripts/launch_multi_extract.sh" "$@"
