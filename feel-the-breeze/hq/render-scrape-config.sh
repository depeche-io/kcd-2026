#!/usr/bin/env bash
# Linux defaults to HQ + the physical Pi. Opt in to the legacy factory VM.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/hq/gitops/apps/kube-prometheus-stack/additional-scrape-configs.yaml"

case "${ENABLE_FACTORY_VM:-0}" in
  1) cat "$SOURCE" ;;
  0)
    # Every scrape job is a top-level YAML list item in this repository.
    awk 'BEGIN {keep=1} /^- job_name:/ {keep=($0 !~ /factory\//)} keep' "$SOURCE"
    ;;
  *) echo "ERROR: ENABLE_FACTORY_VM must be 0 or 1." >&2; exit 1 ;;
esac
