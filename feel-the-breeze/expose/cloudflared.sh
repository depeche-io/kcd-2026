#!/usr/bin/env bash
# Expose Grafana publicly during the talk via a Cloudflare quick tunnel.
# No Cloudflare account or DNS required — `cloudflared` mints a one-shot
# *.trycloudflare.com URL and prints it.
#
# For a more stable URL across rehearsals, switch to a *named* tunnel:
#   cloudflared tunnel login
#   cloudflared tunnel create kcd-demo
#   cloudflared tunnel route dns kcd-demo demo.example.com
#   cloudflared tunnel run --url http://localhost:3000 kcd-demo
set -euo pipefail

CLUSTER="${K3D_CLUSTER:-hq}"
CONTEXT="k3d-$CLUSTER"
LOCAL_PORT=3000
SVC="kube-prometheus-stack-grafana"

if ! command -v cloudflared >/dev/null; then
  echo "cloudflared not found. Install with: brew install cloudflared" >&2
  exit 1
fi

# Background port-forward so the tunnel has something to point at.
echo "==> Port-forwarding $SVC -> localhost:$LOCAL_PORT"
kubectl --context="$CONTEXT" -n monitoring port-forward "svc/$SVC" \
  "$LOCAL_PORT:80" --address 127.0.0.1 >/tmp/grafana-pf.log 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true' EXIT

# Wait for port-forward to be live.
for i in $(seq 1 20); do
  curl -sf "http://localhost:$LOCAL_PORT/api/health" >/dev/null && break
  sleep 1
done

cat <<EOF

==> Launching Cloudflare quick tunnel.
    The public URL appears below as
        Your quick Tunnel has been created! Visit it at:
        https://<random>.trycloudflare.com

    Default Grafana login: admin / prom-operator
    (anonymous Viewer access is enabled — audience can browse without login)

    Press Ctrl-C to stop both the tunnel and the port-forward.
EOF

cloudflared tunnel --url "http://localhost:$LOCAL_PORT" --no-autoupdate
