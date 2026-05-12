#!/usr/bin/env bash
# Port-forward Grafana from the hq cluster and open it in the browser.
set -euo pipefail

CLUSTER="${K3D_CLUSTER:-hq}"
CONTEXT="k3d-$CLUSTER"
LOCAL_PORT=3000

echo "==> Port-forwarding Grafana -> http://localhost:$LOCAL_PORT"
kubectl --context="$CONTEXT" -n monitoring port-forward svc/kube-prometheus-stack-grafana \
  "$LOCAL_PORT:80" --address 127.0.0.1 >/tmp/grafana-pf.log 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true' EXIT

for i in $(seq 1 20); do
  curl -sk --max-time 3 "http://localhost:$LOCAL_PORT/api/health" >/dev/null 2>&1 && break
  sleep 1
done

cat <<EOF

==> Grafana is available at http://localhost:$LOCAL_PORT
    user: admin
    pass: prom-operator
    (anonymous Viewer access is also enabled)

    Press Ctrl-C to stop the port-forward.
EOF

open "http://localhost:$LOCAL_PORT"

wait $PF_PID
