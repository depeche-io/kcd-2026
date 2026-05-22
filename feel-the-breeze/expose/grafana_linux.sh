#!/usr/bin/env bash
# Port-forward Grafana from the hq cluster and open it in the browser.
set -euo pipefail

CLUSTER="${K3D_CLUSTER:-hq}"
CONTEXT="k3d-$CLUSTER"
LOCAL_PORT=3000
URL="http://localhost:$LOCAL_PORT"

open_url() {
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$1" >/dev/null 2>&1 || true
  elif command -v open >/dev/null 2>&1; then
    open "$1" >/dev/null 2>&1 || true
  fi
}

echo "==> Port-forwarding Grafana -> $URL"
kubectl --context="$CONTEXT" -n monitoring port-forward svc/kube-prometheus-stack-grafana \
  "$LOCAL_PORT:80" --address 127.0.0.1 >/tmp/grafana-pf.log 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true' EXIT

for i in $(seq 1 20); do
  curl -sk --max-time 3 "$URL/api/health" >/dev/null 2>&1 && break
  sleep 1
done

cat <<EOF

==> Grafana is available at $URL
    user: admin
    pass: prom-operator
    (anonymous Viewer access is also enabled)

    Press Ctrl-C to stop the port-forward.
EOF

open_url "$URL"
wait $PF_PID
