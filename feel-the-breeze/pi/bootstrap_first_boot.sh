#!/usr/bin/env bash
# Runs on the Pi. A failed/offline attempt is retried by systemd.
set -euo pipefail
umask 077

STATE=/var/lib/kcd-demo
API=/opt/kcd-tuya
# The laptop reads the non-secret ready marker as ubuntu over pinned SSH.
install -d -m 0755 "$STATE"

if [ ! -f "$STATE/packages-ready" ]; then
  timedatectl set-ntp true
  echo "Waiting for clock synchronization before APT..."
  timeout 240 bash -c 'until [ "$(timedatectl show -p NTPSynchronized --value)" = yes ]; do sleep 3; done'
  apt-get -o Acquire::Retries=3 -o Acquire::http::Timeout=30 update
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl ca-certificates avahi-daemon uhubctl raspi-config python3-venv libusb-1.0-0
  touch "$STATE/packages-ready"
fi
systemctl enable --now avahi-daemon

if [ ! -x "$API/.venv/bin/python" ]; then
  python3 -m venv "$API/.venv"
fi
if [ ! -f "$STATE/python-ready" ]; then
  "$API/.venv/bin/pip" install --quiet prometheus-client tinytuya pyusb
  touch "$STATE/python-ready"
fi

if ! command -v k0s >/dev/null; then
  curl -fsSL --retry 3 --connect-timeout 10 https://get.k0s.sh -o /run/kcd-k0s-install.sh
  K0S_VERSION=v1.37.2+k0s.0 sh /run/kcd-k0s-install.sh
fi
if [ ! -f /etc/systemd/system/k0scontroller.service ]; then
  k0s install controller --single
fi
systemctl enable --now k0scontroller.service
timeout 300 bash -c 'until [ -n "$(k0s kubectl get nodes -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)" ]; do sleep 5; done'
k0s kubectl wait nodes --all --for=condition=Ready --timeout=300s

printf '#!/bin/sh\nexec /usr/local/bin/k0s kubectl "$@"\n' > /usr/local/bin/kubectl
chmod 755 /usr/local/bin/kubectl
install -d -m 700 -o ubuntu -g ubuntu /home/ubuntu/.kube
k0s kubeconfig admin | sed 's|https://localhost:6443|https://factory-pi.local:6443|' > /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config
chmod 600 /home/ubuntu/.kube/config

# Find the same devices by ID on the new LAN, retaining their local keys/DPs.
# Missing/unpaired devices leave this attempt pending; systemd retries later.
"$API/.venv/bin/python" "$API/refresh_tuya.py" --env "$API/devices.env"
systemctl daemon-reload
systemctl enable kcd-tuya.service
systemctl restart kcd-tuya.service
timeout 30 bash -c 'until curl -fsS --max-time 2 http://127.0.0.1:8000/healthz >/dev/null; do sleep 2; done'
python3 - <<'PY'
import json, os
from pathlib import Path
path = Path('/var/lib/kcd-demo/ready')
temporary = path.with_suffix('.tmp')
temporary.write_text(json.dumps({
    'instance_id': Path('/etc/kcd-demo/instance-id').read_text().strip(),
    'boot_id': Path('/proc/sys/kernel/random/boot_id').read_text().strip(),
}))
temporary.chmod(0o644)
os.replace(temporary, path)
PY
echo "Pi ready; the laptop can restore HQ registration."
