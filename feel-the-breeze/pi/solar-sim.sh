#!/usr/bin/env bash
# Drive the simulated solar input exposed by the Pi REST API.
# Usage:
#   ./pi/solar-sim.sh sun
#   ./pi/solar-sim.sh cloud
#   ./pi/solar-sim.sh blackout
#   ./pi/solar-sim.sh recover
#   ./pi/solar-sim.sh pulse [count] [on_seconds] [off_seconds]
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
  $0 pulse [count] [on_seconds] [off_seconds]

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
    call "/sun"
    ;;
  cloud)
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
  pulse)
    COUNT="${2:-3}"
    ON_SEC="${3:-15}"
    OFF_SEC="${4:-15}"
    for _ in $(seq 1 "$COUNT"); do
      echo "==> sun (${ON_SEC}s)"
      call "/sun" >/dev/null
      sleep "$ON_SEC"
      echo "==> cloud (${OFF_SEC}s)"
      call "/cloud" >/dev/null
      sleep "$OFF_SEC"
    done
    echo "==> done"
    ;;
  *)
    usage
    exit 1
    ;;
esac
