#!/usr/bin/env bash
# Register the Raspberry Pi (factory-pi) with ArgoCD on HQ and wire up Prometheus scraping.
#
# Prerequisites:
#   - ./factory/up.sh && ./hq/up.sh && ./hq/bootstrap-argocd.sh already done
#   - Pi booted and reachable at factory-pi.local (k0s running, first-boot done)
#
# Idempotent: safe to re-run (refreshes IP in CoreDNS + credentials).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PI_HOST="${PI_HOST:-factory-pi.local}"
PI_USER="${PI_USER:-ubuntu}"
CONTEXT="k3d-${K3D_CLUSTER:-hq}"
SSH="ssh -n -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes"
SSH_STDIN="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes"
K0S_WAIT_ATTEMPTS="${K0S_WAIT_ATTEMPTS:-30}"
K0S_WAIT_SLEEP="${K0S_WAIT_SLEEP:-5}"

cd "$ROOT"

# ---------------------------------------------------------------------------
# 1. Resolve Pi IP.
# ---------------------------------------------------------------------------
echo "==> Resolving $PI_HOST"
PI_IP=$(ping -c1 -W3 "$PI_HOST" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
if [ -z "$PI_IP" ]; then
  echo "ERROR: cannot reach $PI_HOST. Is the Pi up and on the same network?" >&2
  exit 1
fi
echo "    $PI_HOST -> $PI_IP"

# ---------------------------------------------------------------------------
# 2. Wait for k0s API to be ready on the Pi.
# ---------------------------------------------------------------------------
echo "==> Checking SSH access to $PI_USER@$PI_HOST"
if ! SSH_CHECK_OUT=$($SSH "$PI_USER@$PI_HOST" "echo ssh-ok" 2>&1); then
  echo "ERROR: cannot SSH to $PI_USER@$PI_HOST" >&2
  echo "SSH error: $SSH_CHECK_OUT" >&2
  cat >&2 <<'EOF'
Hints:
  - Verify the login user (override with PI_USER=...).
  - Ensure your SSH key is authorized on the Pi.
  - Test manually: ssh <user>@factory-pi.local
EOF
  exit 1
fi
echo "    SSH is reachable"

echo "==> Checking passwordless sudo on $PI_HOST"
if ! SUDO_CHECK_OUT=$($SSH "$PI_USER@$PI_HOST" "sudo -n true" 2>&1); then
  echo "ERROR: sudo without password is required for this script." >&2
  echo "sudo check output: $SUDO_CHECK_OUT" >&2
  echo "Fix on Pi: add NOPASSWD sudo for user '$PI_USER', then re-run." >&2
  exit 1
fi
echo "    sudo -n is available"

echo "==> Detecting Kubernetes runtime on $PI_HOST"
if $SSH "$PI_USER@$PI_HOST" "command -v k0s >/dev/null 2>&1"; then
  PI_KUBECTL_CMD="sudo k0s kubectl"
elif $SSH "$PI_USER@$PI_HOST" "command -v k3s >/dev/null 2>&1"; then
  PI_KUBECTL_CMD="sudo k3s kubectl"
elif $SSH "$PI_USER@$PI_HOST" "command -v microk8s >/dev/null 2>&1"; then
  PI_KUBECTL_CMD="sudo microk8s kubectl"
elif $SSH "$PI_USER@$PI_HOST" "command -v kubectl >/dev/null 2>&1"; then
  PI_KUBECTL_CMD="kubectl"
else
  echo "ERROR: no Kubernetes CLI found on Pi (k0s/k3s/microk8s/kubectl)." >&2
  exit 1
fi
echo "    using '$PI_KUBECTL_CMD'"

echo "==> Validating Kubernetes CLI on $PI_HOST"
if ! KUBE_CHECK_OUT=$($SSH "$PI_USER@$PI_HOST" "$PI_KUBECTL_CMD get nodes 2>&1 || true"); then
  :
fi
if printf %s "$KUBE_CHECK_OUT" | grep -Eq 'k0s: command not found|k3s: command not found|microk8s: command not found'; then
  echo "ERROR: detected a broken kubectl wrapper on the Pi." >&2
  echo "Output: $KUBE_CHECK_OUT" >&2
  cat >&2 <<'EOF'
Likely cause:
  - /usr/local/bin/kubectl points to a runtime binary (k0s/k3s/microk8s) that is not installed.
Fix options:
  1) Re-run Pi cloud-init/flash so k0s is installed as expected.
  2) Install a real runtime on Pi (k0s or k3s), then re-run this script.
EOF
  exit 1
fi

echo "==> Waiting for Kubernetes API on $PI_HOST"
LAST_HEALTH_OUT=""
for i in $(seq 1 "$K0S_WAIT_ATTEMPTS"); do
  HEALTH_OUT=$($SSH "$PI_USER@$PI_HOST" "$PI_KUBECTL_CMD get nodes >/dev/null 2>&1 && echo api:ready || true" 2>&1 || true)
  LAST_HEALTH_OUT="$HEALTH_OUT"
  if printf %s "$HEALTH_OUT" | grep -q '^api:ready$'; then
    echo "    Kubernetes API is ready"
    break
  fi
  echo "    waiting... ($i/$K0S_WAIT_ATTEMPTS)"
  sleep "$K0S_WAIT_SLEEP"
done
if ! printf %s "$LAST_HEALTH_OUT" | grep -q '^api:ready$'; then
  echo "ERROR: Kubernetes API not ready after $((K0S_WAIT_ATTEMPTS * K0S_WAIT_SLEEP))s." >&2
  echo "Last health probe output: ${LAST_HEALTH_OUT:-<empty>}" >&2
  echo "Check: ssh $PI_USER@$PI_HOST '$PI_KUBECTL_CMD get nodes'" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 3. Apply RBAC on the Pi.
# ---------------------------------------------------------------------------
echo "==> Applying hq-controller RBAC on $PI_HOST"
$SSH_STDIN "$PI_USER@$PI_HOST" "$PI_KUBECTL_CMD apply -f -" < "$ROOT/pi/manifests/hq-controller-sa.yaml"

# ---------------------------------------------------------------------------
# 4. Extract bearer token + CA from the Pi.
# ---------------------------------------------------------------------------
echo "==> Extracting hq-controller token from $PI_HOST"
TOKEN=$($SSH "$PI_USER@$PI_HOST" "
  for i in \$(seq 1 30); do
    T=\$($PI_KUBECTL_CMD -n hq-control get secret hq-controller-token \
          -o jsonpath='{.data.token}' 2>/dev/null | base64 -d || true)
    if [ -n \"\$T\" ]; then echo \"\$T\"; exit 0; fi
    sleep 2
  done
  echo 'ERROR: token not populated in time' >&2; exit 1
")
CA=$($SSH "$PI_USER@$PI_HOST" \
  "$PI_KUBECTL_CMD -n hq-control get secret hq-controller-token \
     -o jsonpath='{.data.ca\.crt}'")

kubectl config use-context "$CONTEXT" >/dev/null

# ---------------------------------------------------------------------------
# 4. Patch CoreDNS so k3d pods resolve factory-pi.local -> Pi IP.
# ---------------------------------------------------------------------------
echo "==> Patching CoreDNS: factory-pi.local -> $PI_IP"
HOST_K3D_IP=$(kubectl get cm coredns -n kube-system -o jsonpath='{.data.Corefile}' | awk '/host\.k3d\.internal/{print $1; exit}')
HOST_K3D_IP="${HOST_K3D_IP:-192.168.5.2}"
kubectl patch cm coredns -n kube-system --type=json -p="[{\"op\":\"replace\",\"path\":\"/data/Corefile\",\"value\":\".:53 {\n    errors\n    health\n    ready\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n      pods insecure\n      fallthrough in-addr.arpa ip6.arpa\n    }\n    hosts /etc/coredns/NodeHosts {\n      ${HOST_K3D_IP} host.k3d.internal\n      ${PI_IP} factory-pi.local\n      ttl 60\n      reload 15s\n      fallthrough\n    }\n    prometheus :9153\n    cache 30\n    loop\n    reload\n    loadbalance\n    import /etc/coredns/custom/*.override\n    forward . /etc/resolv.conf\n}\nimport /etc/coredns/custom/*.server\n\"}]"
kubectl rollout restart deployment/coredns -n kube-system
kubectl rollout status deployment/coredns -n kube-system --timeout=60s

# ---------------------------------------------------------------------------
# 5. Register factory-pi as an ArgoCD cluster.
# ---------------------------------------------------------------------------
echo "==> Registering factory-pi cluster in ArgoCD"
kubectl apply -n argocd -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cluster-factory-pi
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: factory-pi
  server: https://${PI_IP}:6443
  config: |
    {
      "bearerToken": "${TOKEN}",
      "tlsClientConfig": {
        "insecure": true
      }
    }
EOF

# ---------------------------------------------------------------------------
# 6. Update factory-pi-credentials for Prometheus.
# ---------------------------------------------------------------------------
echo "==> Updating factory-pi-credentials secret for Prometheus"
kubectl apply -n monitoring -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: factory-pi-credentials
  namespace: monitoring
type: Opaque
data:
  token: $(printf %s "$TOKEN" | base64 | tr -d '\n')
  ca.crt: ${CA}
EOF

kubectl rollout restart statefulset/prometheus-kube-prometheus-stack-prometheus -n monitoring || true

# ---------------------------------------------------------------------------
# 7. Re-apply additional-scrape-configs.
# ---------------------------------------------------------------------------
echo "==> Updating Prometheus additional-scrape-configs"
kubectl -n monitoring create secret generic additional-scrape-configs \
  --from-file=prometheus-additional.yaml=./hq/gitops/apps/kube-prometheus-stack/additional-scrape-configs.yaml \
  --dry-run=client -o yaml | kubectl apply -f -

# ---------------------------------------------------------------------------
# 8. Apply factory-pi ArgoCD Applications.
# ---------------------------------------------------------------------------
echo "==> Applying factory-pi ArgoCD Applications"
kubectl apply -n argocd -f ./hq/gitops/apps/factory-pi-prometheus-crds/application.yaml
kubectl apply -n argocd -f ./hq/gitops/apps/factory-pi-kepler/application.yaml
kubectl apply -n argocd -f ./hq/gitops/apps/factory-pi-exporters/application.yaml

# ---------------------------------------------------------------------------
# 9. Ensure KEDA exists on HQ, then deploy solar-driven fan autoscaling demo.
# ---------------------------------------------------------------------------
echo "==> Ensuring KEDA is installed on HQ"
kubectl apply -n argocd -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: repo-kedacore
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  url: https://kedacore.github.io/charts
  type: helm
  insecure: "true"
  name: kedacore
EOF
kubectl apply -n argocd -f ./hq/gitops/apps/keda/application.yaml

echo "==> Waiting for KEDA CRD (scaledobjects.keda.sh)"
for i in $(seq 1 60); do
  if kubectl get crd scaledobjects.keda.sh >/dev/null 2>&1; then
    break
  fi
  echo "    waiting... ($i/60)"
  sleep 5
done
if ! kubectl get crd scaledobjects.keda.sh >/dev/null 2>&1; then
  echo "ERROR: KEDA CRD scaledobjects.keda.sh not available yet." >&2
  echo "Check ArgoCD app status: kubectl -n argocd get app keda" >&2
  exit 1
fi

echo "==> Deploying smart-vetrak + ScaledObject on HQ"
kubectl apply -f ./hq/manifests/smart-vetrak.yaml

cat <<EOF

==> factory-pi is registered.

    Pi:        $PI_HOST ($PI_IP)
    CoreDNS:   factory-pi.local -> $PI_IP (inside k3d)
    ArgoCD:    cluster 'factory-pi' + 3 Applications (+ KEDA on HQ)
    Prometheus: scraping factory-pi/* via factory-pi.local:6443
    Demo:      smart-vetrak scaled by solar_generation_watts

Check ArgoCD:
    kubectl -n argocd get applications | grep factory-pi

Check scrape targets:
    kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
    xdg-open http://localhost:9090/targets

Test simulation endpoints on Pi:
    curl http://factory-pi.local:8000/sun
    curl http://factory-pi.local:8000/cloud
EOF
