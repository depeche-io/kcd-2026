#!/usr/bin/env bash
# Start the "hq" k3d cluster (k3s in containers) on Linux.
set -euo pipefail

CLUSTER="${K3D_CLUSTER:-hq}"
CONTEXT="k3d-$CLUSTER"
SERVERS="${K3D_SERVERS:-1}"
AGENTS="${K3D_AGENTS:-1}"
# Pin a recent k3s. Override with K3S_IMAGE=rancher/k3s:v1.32.x-k3s1 if needed.
K3S_IMAGE="${K3S_IMAGE:-rancher/k3s:v1.35.4-k3s1}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 not found." >&2
    return 1
  fi
}

if ! require_cmd k3d; then
  cat >&2 <<'EOF'
Install k3d first:
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
EOF
  exit 1
fi

if ! require_cmd kubectl; then
  echo "Install kubectl and re-run." >&2
  exit 1
fi

# Reuse the running cluster even when this shell cannot access its runtime.
# In particular, do not create a second HQ in an unrelated Podman instance.
HAVE_CONTEXT=0
if kubectl config get-contexts "$CONTEXT" -o name 2>/dev/null | grep -Fxq "$CONTEXT"; then
  HAVE_CONTEXT=1
  if kubectl --context="$CONTEXT" --request-timeout=5s get nodes >/dev/null 2>&1; then
    kubectl config use-context "$CONTEXT" >/dev/null
    echo "==> Reusing the reachable HQ cluster: $CONTEXT"
    exit 0
  fi
fi

# Podman Desktop can expose a Docker-compatible API socket.
# Prefer a working default runtime before trying the Podman socket.
if [ -z "${DOCKER_HOST:-}" ] && ! k3d cluster list >/dev/null 2>&1; then
  RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  PODMAN_SOCK="$RUNTIME_DIR/podman/podman.sock"
  if [ -S "$PODMAN_SOCK" ]; then
    if [ "$HAVE_CONTEXT" -eq 1 ] && ! DOCKER_HOST="unix://$PODMAN_SOCK" k3d cluster list -o json 2>/dev/null | grep -q "\"name\": *\"$CLUSTER\""; then
      echo "ERROR: existing context $CONTEXT is unreachable and its cluster is not in Podman." >&2
      echo "Start the original cluster runtime or set DOCKER_HOST to its socket; refusing to create a duplicate." >&2
      exit 1
    fi
    export DOCKER_HOST="unix://$PODMAN_SOCK"
    echo "==> Using Podman socket for k3d: $DOCKER_HOST"
  fi
fi

if ! k3d cluster list >/dev/null 2>&1; then
  cat >&2 <<'EOF'
Cannot reach the container runtime API for k3d.
If you use Podman Desktop, ensure the Docker-compatible socket is enabled.
Typical setup:
  systemctl --user enable --now podman.socket
  export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock
Then run this script again.
EOF
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
kubectl config use-context "$CONTEXT" >/dev/null

# Sanity-check from inside the cluster that it can reach the factory API.
if [ "${ENABLE_FACTORY_VM:-0}" = 1 ]; then
echo "==> Sanity check: hq pod -> factory API via host.k3d.internal"
kubectl run hq-net-check --rm -i --restart=Never \
  --image=curlimages/curl:8.10.1 --quiet -- \
  curl -ks --max-time 3 https://host.k3d.internal:6443/healthz \
  || echo "    (non-zero exit is fine if factory isn't up yet)"
fi

echo "==> hq is up. Current context: $(kubectl config current-context)"
