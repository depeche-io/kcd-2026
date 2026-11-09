#!/usr/bin/env bash
# Read-only diagnostics of the existing HQ, saved privately for inspection.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ "$(id -u)" != 0 ]; then
  echo "Run: sudo bash $0" >&2
  exit 1
fi
DOCKER=(/usr/bin/docker --host unix:///var/run/docker.sock)
for name in k3d-hq-serverlb k3d-hq-server-0 k3d-hq-agent-0; do
  labels="$("${DOCKER[@]}" inspect --format '{{index .Config.Labels "app"}}/{{index .Config.Labels "k3d.cluster"}}' "$name")"
  [ "$labels" = k3d/hq ] || { echo "Unexpected container ownership: $name" >&2; exit 1; }
done
umask 077
LOG="$(mktemp "$ROOT/.local/demo/hq-diagnostic.XXXXXX")"
chown "$(stat -c '%u:%g' "$ROOT")" "$LOG"
{
  date -Is
  "${DOCKER[@]}" inspect k3d-hq-serverlb k3d-hq-server-0 k3d-hq-agent-0 | /usr/bin/python3 -c '
import json,sys
for d in json.load(sys.stdin):
 env=dict(x.split("=",1) for x in d["Config"].get("Env",[]) if "=" in x)
 print(json.dumps({"name":d["Name"],"state":d["State"],
  "networks":d["NetworkSettings"].get("Networks"),
  "connection":{k:env[k] for k in ("K3S_URL","K3S_NODE_IP") if k in env}},indent=2))'
  "${DOCKER[@]}" logs --tail 350 k3d-hq-agent-0 2>&1 || true
  "${DOCKER[@]}" exec k3d-hq-agent-0 sh -c 'ps; ip address; cat /etc/hosts; cat /etc/resolv.conf' 2>&1 || true
  "${DOCKER[@]}" logs --tail 80 k3d-hq-server-0 2>&1 || true
} >"$LOG" 2>&1
echo "Diagnostics saved privately: $LOG"
echo 'The script did not restart or delete any containers.'
