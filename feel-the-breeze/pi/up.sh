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
PI_HOST="factory-pi.local"
PI_USER="ubuntu"
CONTEXT="k3d-${K3D_CLUSTER:-hq}"
SSH="ssh -n -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes"
SSH_STDIN="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes"

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
echo "==> Waiting for k0s API on $PI_HOST"
for i in $(seq 1 30); do
  if $SSH "$PI_USER@$PI_HOST" "curl -sk https://127.0.0.1:6443/healthz" 2>/dev/null | grep -q ok; then
    echo "    k0s is ready"
    break
  fi
  echo "    waiting... ($i/30)"
  sleep 5
done
if ! $SSH "$PI_USER@$PI_HOST" "curl -sk https://127.0.0.1:6443/healthz" 2>/dev/null | grep -q ok; then
  echo "ERROR: k0s API not ready after 150s. Check: ssh $PI_USER@$PI_HOST sudo k0s status" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 3. Apply RBAC on the Pi.
# ---------------------------------------------------------------------------
echo "==> Applying hq-controller RBAC on $PI_HOST"
$SSH_STDIN "$PI_USER@$PI_HOST" "sudo k0s kubectl apply -f -" < "$ROOT/pi/manifests/hq-controller-sa.yaml"

# ---------------------------------------------------------------------------
# 4. Extract bearer token + CA from the Pi.
# ---------------------------------------------------------------------------
echo "==> Extracting hq-controller token from $PI_HOST"
TOKEN=$($SSH "$PI_USER@$PI_HOST" "
  for i in \$(seq 1 30); do
    T=\$(sudo k0s kubectl -n hq-control get secret hq-controller-token \
          -o jsonpath='{.data.token}' 2>/dev/null | base64 -d || true)
    if [ -n \"\$T\" ]; then echo \"\$T\"; exit 0; fi
    sleep 2
  done
  echo 'ERROR: token not populated in time' >&2; exit 1
")
CA=$($SSH "$PI_USER@$PI_HOST" \
  "sudo k0s kubectl -n hq-control get secret hq-controller-token \
     -o jsonpath='{.data.ca\.crt}'")

kubectl config use-context "$CONTEXT" >/dev/null

# ---------------------------------------------------------------------------
# 4. Patch CoreDNS so k3d pods resolve factory-pi.local -> Pi IP.
# ---------------------------------------------------------------------------
echo "==> Patching CoreDNS: factory-pi.local -> $PI_IP"
kubectl patch cm coredns -n kube-system --type=json -p="[{\"op\":\"replace\",\"path\":\"/data/Corefile\",\"value\":\".:53 {\n    errors\n    health\n    ready\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n      pods insecure\n      fallthrough in-addr.arpa ip6.arpa\n    }\n    hosts /etc/coredns/NodeHosts {\n      192.168.5.2 host.k3d.internal\n      ${PI_IP} factory-pi.local\n      ttl 60\n      reload 15s\n      fallthrough\n    }\n    prometheus :9153\n    cache 30\n    loop\n    reload\n    loadbalance\n    import /etc/coredns/custom/*.override\n    forward . /etc/resolv.conf\n}\nimport /etc/coredns/custom/*.server\n\"}]"
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

cat <<EOF

==> factory-pi is registered.

    Pi:        $PI_HOST ($PI_IP)
    CoreDNS:   factory-pi.local -> $PI_IP (inside k3d)
    ArgoCD:    cluster 'factory-pi' + 3 Applications
    Prometheus: scraping factory-pi/* via factory-pi.local:6443

Check ArgoCD:
    kubectl -n argocd get applications | grep factory-pi

Check scrape targets:
    kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
    open http://localhost:9090/targets
EOF
