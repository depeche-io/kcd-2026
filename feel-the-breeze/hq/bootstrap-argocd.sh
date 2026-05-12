#!/usr/bin/env bash
# Bootstrap ArgoCD on the hq k3d cluster, register the factory cluster,
# and apply the ArgoCD Applications.
#
# No git write access needed — ArgoCD is installed directly from a pinned
# manifest and all Applications source from Helm chart repos.
set -euo pipefail

ARGOCD_VERSION="v3.4.1"
ARGOCD_INSTALL_URL="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER="${K3D_CLUSTER:-hq}"
CONTEXT="k3d-$CLUSTER"

cd "$ROOT"

if [ ! -f ./factory.kubeconfig.host ]; then
  echo "factory.kubeconfig.host is missing. Run ./factory/up.sh first." >&2
  exit 1
fi

kubectl config use-context "$CONTEXT" >/dev/null

# ---------------------------------------------------------------------------
# 1. Install ArgoCD from a pinned manifest (idempotent).
# ---------------------------------------------------------------------------
echo "==> Installing ArgoCD ${ARGOCD_VERSION}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side --force-conflicts -f "$ARGOCD_INSTALL_URL"

echo "==> Configuring ArgoCD server for insecure (HTTP) mode"
kubectl patch deploy argocd-server -n argocd \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"argocd-server","args":["argocd-server","--insecure"]}]}}}}'

echo "==> Patching CoreDNS: host.k3d.internal -> 192.168.5.2 (Docker Desktop host gateway)"
kubectl patch cm coredns -n kube-system --type=json -p='[{"op":"replace","path":"/data/Corefile","value":".:53 {\n    errors\n    health\n    ready\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n      pods insecure\n      fallthrough in-addr.arpa ip6.arpa\n    }\n    hosts /etc/coredns/NodeHosts {\n      192.168.5.2 host.k3d.internal\n      ttl 60\n      reload 15s\n      fallthrough\n    }\n    prometheus :9153\n    cache 30\n    loop\n    reload\n    loadbalance\n    import /etc/coredns/custom/*.override\n    forward . /etc/resolv.conf\n}\nimport /etc/coredns/custom/*.server\n"}]'
kubectl rollout restart deployment/coredns -n kube-system
kubectl rollout status deployment/coredns -n kube-system --timeout=60s

echo "==> Waiting for ArgoCD to be ready"
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s

# ---------------------------------------------------------------------------
# 2. Register the factory cluster as an ArgoCD destination (Secret in argocd ns).
# ---------------------------------------------------------------------------
echo "==> Registering factory cluster"
# factory-pi placeholder — pi/up.sh overwrites this with real credentials once the Pi is up.
kubectl apply -n argocd -f - <<'EOF'
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
  server: https://factory-pi.local:6443
  config: |
    {
      "bearerToken": "placeholder",
      "tlsClientConfig": {
        "insecure": true
      }
    }
EOF

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
        "insecure": true
      }
    }
EOF

# ---------------------------------------------------------------------------
# 3. Make the factory bearer token available to HQ Prometheus so it can
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

# factory-pi-credentials: placeholder so Prometheus can mount the volume at
# startup even before the Pi is registered. pi/up.sh fills in real values.
kubectl apply -n monitoring -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: factory-pi-credentials
  namespace: monitoring
type: Opaque
data:
  token: cGxhY2Vob2xkZXI=
  ca.crt: cGxhY2Vob2xkZXI=
EOF

# additionalScrapeConfigs Secret consumed by kube-prometheus-stack.
kubectl -n monitoring create secret generic additional-scrape-configs \
  --from-file=prometheus-additional.yaml=./hq/gitops/apps/kube-prometheus-stack/additional-scrape-configs.yaml \
  --dry-run=client -o yaml | kubectl apply -f -

# ---------------------------------------------------------------------------
# 4. Prepare k3d nodes for Kepler: create /usr/src (required hostPath for eBPF).
#    k3d nodes are Docker containers and don't have this directory by default.
# ---------------------------------------------------------------------------
echo "==> Preparing k3d nodes for Kepler (/usr/src)"
for node in $(kubectl get nodes -o name | sed 's|node/||'); do
  docker exec "$node" mkdir -p /usr/src 2>/dev/null || true
done

# ---------------------------------------------------------------------------
# 5. Register Helm repositories (insecure=true to handle corporate TLS proxy).
# ---------------------------------------------------------------------------
echo "==> Registering Helm repositories"
kubectl apply -n argocd -f - <<'HELMREPOS'
apiVersion: v1
kind: Secret
metadata:
  name: repo-prometheus-community
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  url: https://prometheus-community.github.io/helm-charts
  type: helm
  insecure: "true"
  name: prometheus-community
---
apiVersion: v1
kind: Secret
metadata:
  name: repo-kepler
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  url: https://sustainable-computing-io.github.io/kepler-helm-chart
  type: helm
  insecure: "true"
  name: kepler
HELMREPOS

# ---------------------------------------------------------------------------
# 6. Apply the ArgoCD Applications.
# ---------------------------------------------------------------------------
echo "==> Applying ArgoCD Applications"
kubectl apply -n argocd -f ./hq/gitops/apps/kube-prometheus-stack/application.yaml
kubectl apply -n argocd -f ./hq/gitops/apps/factory-prometheus-crds/application.yaml
kubectl apply -n argocd -f ./hq/gitops/apps/factory-kepler/application.yaml
kubectl apply -n argocd -f ./hq/gitops/apps/factory-exporters/application.yaml
kubectl apply -n argocd -f ./hq/gitops/apps/factory-pi-prometheus-crds/application.yaml
kubectl apply -n argocd -f ./hq/gitops/apps/factory-pi-kepler/application.yaml
kubectl apply -n argocd -f ./hq/gitops/apps/factory-pi-exporters/application.yaml

echo "==> Waiting for kube-prometheus-stack to sync (this can take a few minutes)"
for i in $(seq 1 60); do
  PHASE=$(kubectl -n argocd get application kube-prometheus-stack \
            -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null || true)
  echo "    kube-prometheus-stack: ${PHASE}"
  [ "$PHASE" = "Synced/Healthy" ] && break
  sleep 10
done

# ---------------------------------------------------------------------------
# 7. Print access info.
# ---------------------------------------------------------------------------
ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)

cat <<EOF

==> hq is bootstrapped.

ArgoCD UI:
    ./expose/argocd.sh
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
