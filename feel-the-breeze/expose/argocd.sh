#!/usr/bin/env bash
# Port-forward ArgoCD UI from the hq cluster and open it in the browser.
set -euo pipefail

CLUSTER="${K3D_CLUSTER:-hq}"
CONTEXT="k3d-$CLUSTER"
LOCAL_PORT=8080

echo "==> Port-forwarding ArgoCD -> http://localhost:$LOCAL_PORT"
kubectl --context="$CONTEXT" -n argocd port-forward svc/argocd-server \
  "$LOCAL_PORT:80" --address 127.0.0.1 >/tmp/argocd-pf.log 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true' EXIT

for i in $(seq 1 20); do
  curl -sk --max-time 3 "http://localhost:$LOCAL_PORT" >/dev/null 2>&1 && break
  sleep 1
done

ARGOCD_PWD=$(kubectl --context="$CONTEXT" -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "(secret not yet available)")

cat <<EOF

==> ArgoCD is available at http://localhost:$LOCAL_PORT
    user: admin
    pass: ${ARGOCD_PWD}

    Press Ctrl-C to stop the port-forward.
EOF

open "http://localhost:$LOCAL_PORT"

wait $PF_PID
