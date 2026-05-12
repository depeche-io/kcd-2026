#!/usr/bin/env bash
# Bootstrap ArgoCD on the hq k3d cluster using argocd-autopilot,
# register the factory cluster, and apply the ArgoCD Applications.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER="${K3D_CLUSTER:-hq}"
CONTEXT="k3d-$CLUSTER"

cd "$ROOT"

: "${GIT_REPO:?Set GIT_REPO (and GIT_TOKEN) — see .env.example}"
: "${GIT_TOKEN:?Set GIT_TOKEN — see .env.example}"

if [ ! -f ./factory.kubeconfig.host ]; then
  echo "factory.kubeconfig.host is missing. Run ./factory/up.sh first." >&2
  exit 1
fi

kubectl config use-context "$CONTEXT" >/dev/null

# ---------------------------------------------------------------------------
# 1. Bootstrap ArgoCD via argocd-autopilot (idempotent — checks namespace).
# ---------------------------------------------------------------------------
if kubectl get ns argocd >/dev/null 2>&1; then
  echo "==> argocd namespace already exists; skipping autopilot bootstrap"
else
  echo "==> Running argocd-autopilot repo bootstrap"
  argocd-autopilot repo bootstrap \
    --repo "$GIT_REPO" \
    --git-token "$GIT_TOKEN" \
    --provider github
fi

echo "==> Waiting for ArgoCD to be ready"
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s

# ---------------------------------------------------------------------------
# 2. Ensure the default AppProject exists (autopilot pattern).
# ---------------------------------------------------------------------------
if ! kubectl -n argocd get appproject default >/dev/null 2>&1 \
   || [ "$(kubectl -n argocd get appproject default -o jsonpath='{.spec.sourceRepos}' 2>/dev/null)" = '["*"]' ]; then
  echo "==> Creating 'default' project via argocd-autopilot"
  argocd-autopilot project create default \
    --repo "$GIT_REPO" \
    --git-token "$GIT_TOKEN" || true
fi

# ---------------------------------------------------------------------------
# 3. Register the factory cluster as an ArgoCD destination (Secret in argocd ns).
# ---------------------------------------------------------------------------
echo "==> Registering factory cluster"
SERVER=$(awk '/server:/{print $2; exit}' ./factory.kubeconfig.host)
CA=$(awk '/certificate-authority-data:/{print $2; exit}' ./factory.kubeconfig.host)
TOKEN=$(awk '/token:/{print $2; exit}' ./factory.kubeconfig.host)

kubectl apply -n argocd -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cluster-factory
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: factory
  server: ${SERVER}
  config: |
    {
      "bearerToken": "${TOKEN}",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "${CA}"
      }
    }
EOF

# ---------------------------------------------------------------------------
# 4. Make the factory bearer token available to HQ Prometheus so it can
#    scrape factory through /api/v1/.../proxy/ endpoints.
# ---------------------------------------------------------------------------
echo "==> Storing factory credentials for Prometheus scrape jobs"
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# factory-credentials: token + CA, mounted into the Prometheus pod via
# `prometheus.spec.secrets: [factory-credentials]` in the Helm values.
kubectl apply -n monitoring -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: factory-credentials
  namespace: monitoring
type: Opaque
data:
  token: $(printf %s "$TOKEN" | base64 | tr -d '\n')
  ca.crt: ${CA}
EOF

# additionalScrapeConfigs Secret consumed by kube-prometheus-stack.
kubectl -n monitoring create secret generic additional-scrape-configs \
  --from-file=prometheus-additional.yaml=./hq/gitops/apps/kube-prometheus-stack/additional-scrape-configs.yaml \
  --dry-run=client -o yaml | kubectl apply -f -

# ---------------------------------------------------------------------------
# 5. Apply the ArgoCD Applications.
# ---------------------------------------------------------------------------
echo "==> Applying ArgoCD Applications"
kubectl apply -n argocd -f ./hq/gitops/apps/kube-prometheus-stack/application.yaml
kubectl apply -n argocd -f ./hq/gitops/apps/kepler/application.yaml
kubectl apply -n argocd -f ./hq/gitops/apps/factory-exporters/application.yaml

echo "==> Waiting for kube-prometheus-stack to sync (this can take a few minutes)"
for i in $(seq 1 60); do
  PHASE=$(kubectl -n argocd get application kube-prometheus-stack \
            -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null || true)
  echo "    kube-prometheus-stack: ${PHASE}"
  [ "$PHASE" = "Synced/Healthy" ] && break
  sleep 10
done

# ---------------------------------------------------------------------------
# 6. Print access info.
# ---------------------------------------------------------------------------
ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)

cat <<EOF

==> hq is bootstrapped.

ArgoCD UI:
    kubectl -n argocd port-forward svc/argocd-server 8080:80
    open http://localhost:8080
    user: admin
    pass: ${ARGOCD_PWD:-(not yet generated — wait a moment and re-check)}

Grafana:
    kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
    open http://localhost:3000
    user: admin
    pass: prom-operator   (default; overridden in values.yaml if changed)

Public exposure for the talk:
    ./expose/cloudflared.sh
EOF
