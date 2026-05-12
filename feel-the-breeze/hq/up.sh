#!/usr/bin/env bash
# Start the "hq" k3d cluster.
set -euo pipefail

CLUSTER="${K3D_CLUSTER:-hq}"
SERVERS="${K3D_SERVERS:-1}"
AGENTS="${K3D_AGENTS:-1}"
# Pin a recent k3s. Override with K3S_IMAGE=rancher/k3s:v1.32.x-k3s1 if needed.
K3S_IMAGE="${K3S_IMAGE:-rancher/k3s:v1.35.4-k3s1}"

if ! command -v k3d >/dev/null; then
  echo "k3d not found. Install with: brew install k3d" >&2
  exit 1
fi

echo "==> Creating k3d cluster '$CLUSTER' (servers=$SERVERS agents=$AGENTS image=$K3S_IMAGE)"
if k3d cluster list -o json 2>/dev/null | grep -q "\"name\": *\"$CLUSTER\""; then
  echo "    cluster already exists; ensuring it is running"
  k3d cluster start "$CLUSTER" >/dev/null 2>&1 || true
else
  # No --port mapping for Grafana — we use kubectl port-forward + cloudflared.
  # Disable the bundled Traefik to keep things lightweight (we don't use ingress).
  k3d cluster create "$CLUSTER" \
    --image "$K3S_IMAGE" \
    --servers "$SERVERS" \
    --agents  "$AGENTS" \
    --k3s-arg '--disable=traefik@server:*' \
    --wait
fi

# k3d names the kubeconfig context "k3d-<cluster>".
CONTEXT="k3d-$CLUSTER"
kubectl config use-context "$CONTEXT" >/dev/null

# Sanity-check from inside the cluster that it can reach the factory API.
echo "==> Sanity check: hq pod -> factory API via host.k3d.internal"
kubectl run hq-net-check --rm -i --restart=Never \
  --image=curlimages/curl:8.10.1 --quiet -- \
  curl -ks --max-time 3 https://host.k3d.internal:6443/healthz \
  || echo "    (non-zero exit is fine if factory isn't up yet)"

echo "==> hq is up. Current context: $(kubectl config current-context)"
