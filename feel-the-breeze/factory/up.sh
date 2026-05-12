#!/usr/bin/env bash
# Bring up the "factory" cluster: Lima VM with k0s, RBAC for HQ, exporters.
# Idempotent: re-running on an existing VM only re-applies manifests.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VM_NAME="${FACTORY_VM_NAME:-factory}"

cd "$ROOT"

if ! command -v limactl >/dev/null; then
  echo "limactl not found. Install with: brew install lima" >&2
  exit 1
fi

echo "==> Creating Lima VM '$VM_NAME' (if missing)"
if limactl list -q | grep -qx "$VM_NAME"; then
  STATUS=$(limactl list -f '{{.Status}}' "$VM_NAME")
  echo "    VM '$VM_NAME' exists (status: $STATUS)"
  if [ "$STATUS" != "Running" ]; then
    if ! limactl start "$VM_NAME"; then
      echo
      echo "ERROR: failed to start VM '$VM_NAME'." >&2
      echo "It was likely created from an older template. Recreate with:" >&2
      echo "    ./factory/down.sh && ./factory/up.sh" >&2
      exit 1
    fi
  fi
else
  limactl start --name="$VM_NAME" --tty=false ./factory/lima-k0s.yaml
fi

echo "==> Fetching kubeconfig from the VM"
# admin.conf points at 127.0.0.1:6443 inside the VM, which is what we want
# because the VM forwards 6443 to the host.
limactl shell "$VM_NAME" sudo cat /var/lib/k0s/pki/admin.conf > ./factory.kubeconfig.raw

# Two variants:
#   factory.kubeconfig       -> server: https://127.0.0.1:6443         (use from host shell)
#   factory.kubeconfig.host  -> server: https://host.k3d.internal:6443  (use from k3d pods)
sed 's|server: https://.*:6443|server: https://127.0.0.1:6443|' ./factory.kubeconfig.raw > ./factory.kubeconfig
sed 's|server: https://.*:6443|server: https://host.k3d.internal:6443|' ./factory.kubeconfig.raw > ./factory.kubeconfig.host
rm -f ./factory.kubeconfig.raw
chmod 600 ./factory.kubeconfig ./factory.kubeconfig.host

echo "==> Waiting for the API to answer on host port 6443"
for i in $(seq 1 30); do
  if KUBECONFIG=./factory.kubeconfig kubectl get --raw=/healthz >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo "==> Applying HQ controller RBAC (exporters will be deployed by ArgoCD)"
KUBECONFIG=./factory.kubeconfig kubectl apply -f ./factory/manifests/hq-controller-sa.yaml

echo "==> Extracting hq-controller token"
# Wait for the token controller to populate the secret
for i in $(seq 1 30); do
  TOKEN=$(KUBECONFIG=./factory.kubeconfig kubectl -n hq-control get secret hq-controller-token \
            -o jsonpath='{.data.token}' 2>/dev/null | base64 -d || true)
  [ -n "$TOKEN" ] && break
  sleep 1
done
if [ -z "${TOKEN:-}" ]; then
  echo "Failed to read hq-controller token" >&2
  exit 1
fi

CA=$(KUBECONFIG=./factory.kubeconfig kubectl -n hq-control get secret hq-controller-token \
       -o jsonpath='{.data.ca\.crt}')

# Build a kubeconfig HQ will use to talk to factory (server URL is the one
# k3d pods can reach).
cat > ./factory.kubeconfig.host <<EOF
apiVersion: v1
kind: Config
clusters:
  - name: factory
    cluster:
      server: https://host.k3d.internal:6443
      certificate-authority-data: ${CA}
contexts:
  - name: factory
    context:
      cluster: factory
      user: hq-controller
current-context: factory
users:
  - name: hq-controller
    user:
      token: ${TOKEN}
EOF
chmod 600 ./factory.kubeconfig.host

cat <<EOF

==> factory is up.
    VM:               $VM_NAME ($(limactl list -f '{{.Status}}' "$VM_NAME"))
    Local kubeconfig: $ROOT/factory.kubeconfig
    HQ kubeconfig:    $ROOT/factory.kubeconfig.host

Try it:
    KUBECONFIG=$ROOT/factory.kubeconfig kubectl get nodes
EOF
