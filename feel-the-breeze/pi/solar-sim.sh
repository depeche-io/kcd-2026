#!/usr/bin/env bash
# Helper for Pi solar-control API (real meter mode).
# Usage:
#   ./pi/solar-sim.sh sun
#   ./pi/solar-sim.sh cloud
#   ./pi/solar-sim.sh blackout
#   ./pi/solar-sim.sh recover
#   ./pi/solar-sim.sh state
set -euo pipefail

BASE_URL="${SOLAR_API_BASE_URL:-http://factory-pi.local:8000}"
MODE="${1:-}"

usage() {
  cat <<EOF
Usage:
  $0 sun
  $0 cloud
  $0 blackout
  $0 off
  $0 recover
  $0 state

Env:
  SOLAR_API_BASE_URL   default: http://factory-pi.local:8000
EOF
}

call() {
  local path="$1"
  curl -fsS "${BASE_URL}${path}"
  echo
}

case "$MODE" in
  sun)
    # In real-meter mode this is informational only.
    call "/sun"
    ;;
  cloud)
    # In real-meter mode this is informational only.
    call "/cloud"
    ;;
  blackout|off)
    # Native API endpoint: no solar generation + force both devices off.
    call "/blackout"
    ;;
  recover)
    # Native API endpoint: raise simulated solar + force fan back on.
    call "/recover"
    ;;
  state)
    call "/state"
    ;;
  *)
    usage
    exit 1
    ;;
esac
