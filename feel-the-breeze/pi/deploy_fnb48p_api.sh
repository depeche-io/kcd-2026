#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PI_HOST="${PI_HOST:-factory-pi.local}"
PI_USER="${PI_USER:-ubuntu}"
API_SRC="${API_SRC:-$ROOT/pi/fnb48p_power_api.py}"
API_DST="${API_DST:-/opt/kcd-tuya/simulation.py}"
VENV_PIP="${VENV_PIP:-/opt/kcd-tuya/.venv/bin/pip}"

if [[ ! -f "$API_SRC" ]]; then
  echo "ERROR: source file not found: $API_SRC" >&2
  exit 1
fi

echo "==> Deploying $API_SRC to $PI_USER@$PI_HOST:$API_DST"
cat "$API_SRC" | ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" "sudo tee '$API_DST' >/dev/null"

echo "==> Installing Python deps (pyusb)"
ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" "sudo '$VENV_PIP' install --quiet pyusb"

echo "==> Restarting kcd-tuya service"
ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" "sudo systemctl restart kcd-tuya.service"

echo "==> Service status"
ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" "sudo systemctl --no-pager --full status kcd-tuya.service | sed -n '1,120p'"

echo "==> API state"
ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" "curl -fsS http://127.0.0.1:8000/state && echo"
