#!/usr/bin/env bash
# Refresh only the existing HQ nodes' resolver after changing the laptop network.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCKER=(/usr/bin/docker --host unix:///var/run/docker.sock)
if [ "$(id -u)" != 0 ]; then
  echo "Run: sudo bash $0" >&2
  exit 1
fi
for name in k3d-hq-server-0 k3d-hq-agent-0; do
  labels="$("${DOCKER[@]}" inspect --format '{{index .Config.Labels "app"}}/{{index .Config.Labels "k3d.cluster"}}' "$name")"
  [ "$labels" = k3d/hq ] || { echo "Unexpected container ownership: $name" >&2; exit 1; }
  [ "$("${DOCKER[@]}" inspect --format '{{.State.Running}}' "$name")" = true ] || {
    echo "HQ node is not running: $name" >&2; exit 1;
  }
done
DNS_CONFIG="$(/usr/bin/python3 - <<'PY'
import ipaddress
from pathlib import Path
servers = []
for path in ('/run/systemd/resolve/resolv.conf', '/etc/resolv.conf'):
    if not Path(path).exists():
        continue
    for line in Path(path).read_text().splitlines():
        fields = line.split()
        if len(fields) < 2 or fields[0] != 'nameserver':
            continue
        address = ipaddress.ip_address(fields[1])
        if address.is_loopback or address.is_unspecified or address.is_link_local:
            continue
        if str(address) not in servers:
            servers.append(str(address))
    if servers:
        break
if not servers:
    raise SystemExit('No usable laptop DNS upstream; connect Wi-Fi first.')
print('# HQ upstream DNS refreshed from the laptop network')
for address in servers[:3]:
    print('nameserver ' + address)
print('options ndots:0')
PY
)"
umask 077
install -d -m 0700 -o "$(stat -c %u "$ROOT")" -g "$(stat -c %g "$ROOT")" "$ROOT/.local/demo"
for name in k3d-hq-server-0 k3d-hq-agent-0; do
  before="$("${DOCKER[@]}" exec "$name" cat /etc/resolv.conf)"
  if [ "$before" = "$DNS_CONFIG" ]; then
    echo "$name: DNS already current"
    continue
  fi
  backup="$(mktemp "$ROOT/.local/demo/$name-resolv.XXXXXX")"
  printf '%s\n' "$before" > "$backup"
  chown "$(stat -c '%u:%g' "$ROOT")" "$backup"
  printf '%s\n' "$DNS_CONFIG" | "${DOCKER[@]}" exec -i "$name" sh -c 'cat > /etc/resolv.conf'
  echo "$name: DNS refreshed; previous resolver saved to $backup"
done
echo 'HQ DNS updated. Existing containers and cluster data retained.'
