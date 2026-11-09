#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PI_HOST="${PI_HOST:-factory-pi.local}"
PI_USER="${PI_USER:-ubuntu}"
API_SRC="${API_SRC:-$ROOT/pi/fnb48p_power_api.py}"
API_DST="${API_DST:-/opt/kcd-tuya/simulation.py}"
VENV_PIP="${VENV_PIP:-/opt/kcd-tuya/.venv/bin/pip}"
API_DIR="$(dirname "$API_DST")"
VENV_PYTHON="$(dirname "$VENV_PIP")/python"
SSH=(ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=yes "$PI_USER@$PI_HOST")

if [[ ! -f "$API_SRC" ]]; then
  echo "ERROR: source file not found: $API_SRC" >&2
  exit 1
fi

echo "==> Preparing API directory and Python environment"
printf -v SETUP_ARGS '%q ' "$API_DIR" "$VENV_PYTHON" "$VENV_PIP"
"${SSH[@]}" "sudo -n bash -s -- $SETUP_ARGS" <<'REMOTE'
set -euo pipefail
API_DIR="$1"
VENV_PYTHON="$2"
VENV_PIP="$3"

if [ "$(dpkg-query -W -f='${Status}\n' python3-venv libusb-1.0-0 2>/dev/null | grep -cFx 'install ok installed' || true)" != 2 ]; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y python3-venv libusb-1.0-0
fi
install -d -m 755 "$API_DIR"
if [ ! -x "$VENV_PYTHON" ]; then
  python3 -m venv "$(dirname "$(dirname "$VENV_PYTHON")")"
fi
"$VENV_PIP" install --quiet prometheus-client tinytuya pyusb

# Keep device credentials across deployments; never print their values.
if [ ! -e "$API_DIR/devices.env" ]; then
  install -m 600 /dev/null "$API_DIR/devices.env"
  cat > "$API_DIR/devices.env" <<'ENV'
# Fill in the real device values, then restart kcd-tuya.service.
# TUYA_FAN_DEVICE_ID=
# TUYA_FAN_IP=
# TUYA_FAN_LOCAL_KEY=
# TUYA_FAN_VERSION=3.3
# TUYA_FAN_SWITCH_DP=1
# TUYA_LED_DEVICE_ID=
# TUYA_LED_IP=
# TUYA_LED_LOCAL_KEY=
# TUYA_LED_VERSION=3.3
# TUYA_LED_SWITCH_DP=1
ENV
fi
chmod 600 "$API_DIR/devices.env"
REMOTE

echo "==> Deploying $API_SRC to $PI_USER@$PI_HOST:$API_DST"
printf -v QUOTED_DST '%q' "$API_DST"
"${SSH[@]}" "sudo -n tee $QUOTED_DST >/dev/null" < "$API_SRC"

echo "==> Ensuring systemd service exists"
printf -v SERVICE_ARGS '%q ' "$API_DIR" "$VENV_PYTHON" "$API_DST"
"${SSH[@]}" "sudo -n bash -s -- $SERVICE_ARGS" <<'REMOTE'
set -euo pipefail
API_DIR="$1"
VENV_PYTHON="$2"
API_DST="$3"
LOAD_STATE="$(systemctl show kcd-tuya.service -p LoadState --value)"
if [ "$LOAD_STATE" = not-found ]; then
  cat > /etc/systemd/system/kcd-tuya.service <<EOF
[Unit]
Description=KCD Tuya and FNB48P API
Wants=network-online.target
After=network-online.target

[Service]
WorkingDirectory=$API_DIR
EnvironmentFile=$API_DIR/devices.env
Environment=PYTHONUNBUFFERED=1
ExecStart="$VENV_PYTHON" "$API_DST"
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
fi
systemctl daemon-reload
systemd-analyze verify "$(systemctl show kcd-tuya.service -p FragmentPath --value)"
systemctl enable kcd-tuya.service
systemctl restart kcd-tuya.service
REMOTE

echo "==> Waiting for API health"
"${SSH[@]}" 'for i in $(seq 1 20); do
  if curl -fsS --max-time 2 http://127.0.0.1:8000/healthz 2>/dev/null; then
    printf "\n"
    exit 0
  fi
  sleep 1
done
echo "ERROR: API did not become healthy; check journalctl -u kcd-tuya.service" >&2
exit 1'

echo "==> Service status"
"${SSH[@]}" "sudo -n systemctl --no-pager --full status kcd-tuya.service | sed -n '1,40p'"

echo "==> API state"
"${SSH[@]}" "curl -fsS --max-time 5 http://127.0.0.1:8000/state && echo"
echo "Device credentials: $API_DIR/devices.env on $PI_HOST (required for fan/LED control)."
