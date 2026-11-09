#!/usr/bin/env bash
# Bootstrap ArgoCD on the hq k3d cluster, register the factory cluster,
# and apply the ArgoCD Applications.
#
# Linux variant: avoids hardcoded Docker Desktop IP and docker CLI dependency.
set -euo pipefail

ARGOCD_VERSION="v3.4.1"
ARGOCD_INSTALL_URL="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER="${K3D_CLUSTER:-hq}"
CONTEXT="k3d-$CLUSTER"
FACTORY_KUBECONFIG="${FACTORY_KUBECONFIG:-./factory.kubeconfig.host}"
ENABLE_FACTORY_VM="${ENABLE_FACTORY_VM:-0}"
export ENABLE_FACTORY_VM

cd "$ROOT"

case "$ENABLE_FACTORY_VM" in
  0) HAVE_FACTORY=0; echo "==> Using HQ + Pi mode (register the Pi with ./pi/up_linux.sh)." ;;
  1)
    if [ ! -f "$FACTORY_KUBECONFIG" ]; then
      echo "ERROR: $FACTORY_KUBECONFIG is missing; prepare the factory VM first." >&2
      exit 1
    fi
    HAVE_FACTORY=1
    ;;
  *) echo "ERROR: ENABLE_FACTORY_VM must be 0 or 1." >&2; exit 1 ;;
esac

kubectl config use-context "$CONTEXT" >/dev/null

echo "==> Installing ArgoCD ${ARGOCD_VERSION}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side --force-conflicts -f "$ARGOCD_INSTALL_URL"

echo "==> Configuring ArgoCD server for insecure (HTTP) mode"
kubectl patch deploy argocd-server -n argocd \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"argocd-server","args":["argocd-server","--insecure"]}]}}}}'

if [ "$HAVE_FACTORY" -eq 1 ]; then
echo "==> Checking host.k3d.internal DNS from inside the cluster"
if kubectl run hq-dns-check --rm -i --restart=Never --image=busybox:1.36 --quiet -- nslookup host.k3d.internal >/dev/null 2>&1; then
  echo "    host.k3d.internal resolves correctly"
else
  cat <<'EOF'
    WARNING: host.k3d.internal did not resolve from a test pod.
    If factory registration fails, recreate the k3d cluster without --no-hostip.
EOF
fi
fi

echo "==> Waiting for ArgoCD to be ready"
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s

echo "==> Ensuring factory-pi registration exists"
if ! kubectl get secret cluster-factory-pi -n argocd >/dev/null 2>&1; then
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
fi

if [ "$HAVE_FACTORY" -eq 1 ]; then
  echo "==> Registering factory cluster"
  SERVER=$(awk '/server:/{print $2; exit}' "$FACTORY_KUBECONFIG")
  CA=$(awk '/certificate-authority-data:/{print $2; exit}' "$FACTORY_KUBECONFIG")
  TOKEN=$(awk '/token:/{print $2; exit}' "$FACTORY_KUBECONFIG")
else
  SERVER="https://host.k3d.internal:6443"
  CA="cGxhY2Vob2xkZXI="
  TOKEN="placeholder"
fi

if [ "$HAVE_FACTORY" -eq 1 ]; then
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
fi

echo "==> Storing factory credentials for Prometheus scrape jobs"
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

if [ "$HAVE_FACTORY" -eq 1 ] || ! kubectl get secret factory-credentials -n monitoring >/dev/null 2>&1; then
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
fi

if ! kubectl get secret factory-pi-credentials -n monitoring >/dev/null 2>&1; then
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
fi

"$ROOT/hq/render-scrape-config.sh" | kubectl -n monitoring create secret generic additional-scrape-configs \
  --from-file=prometheus-additional.yaml=/dev/stdin \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Preparing k3d nodes for Kepler (/usr/src)"
kubectl apply -n kube-system -f - <<'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kepler-prepare-usrsrc
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: kepler-prepare-usrsrc
  template:
    metadata:
      labels:
        app: kepler-prepare-usrsrc
    spec:
      tolerations:
      - operator: Exists
      containers:
      - name: prepare
        image: busybox:1.36
        command:
        - sh
        - -c
        - mkdir -p /host/usr/src && sleep 3600
        securityContext:
          privileged: true
        volumeMounts:
        - name: host-root
          mountPath: /host
      volumes:
      - name: host-root
        hostPath:
          path: /
          type: Directory
EOF
kubectl -n kube-system rollout status daemonset/kepler-prepare-usrsrc --timeout=120s || true
kubectl -n kube-system delete daemonset/kepler-prepare-usrsrc --ignore-not-found=true

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

echo "==> Applying ArgoCD Applications"
kubectl apply -n argocd -f ./hq/gitops/apps/kube-prometheus-stack/application.yaml
if [ "$HAVE_FACTORY" -eq 1 ]; then
  kubectl apply -n argocd -f ./hq/gitops/apps/factory-prometheus-crds/application.yaml
  kubectl apply -n argocd -f ./hq/gitops/apps/factory-kepler/application.yaml
  kubectl apply -n argocd -f ./hq/gitops/apps/factory-exporters/application.yaml
  kubectl apply -n argocd -f ./hq/gitops/apps/factory-pi-prometheus-crds/application.yaml
  kubectl apply -n argocd -f ./hq/gitops/apps/factory-pi-kepler/application.yaml
  kubectl apply -n argocd -f ./hq/gitops/apps/factory-pi-exporters/application.yaml
else
  echo "==> Skipping legacy factory VM Applications; ./pi/up_linux.sh registers the physical Pi"
fi

echo "==> Waiting for kube-prometheus-stack to sync (this can take a few minutes)"
for i in $(seq 1 60); do
  PHASE=$(kubectl -n argocd get application kube-prometheus-stack \
            -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null || true)
  echo "    kube-prometheus-stack: ${PHASE}"
  [ "$PHASE" = "Synced/Healthy" ] && break
  sleep 10
done

ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)

cat <<EOF

==> hq is bootstrapped.

ArgoCD UI:
    ./expose/argocd_linux.sh
    user: admin
    pass: ${ARGOCD_PWD:-(not yet generated - wait a moment and re-check)}

Grafana:
    ./expose/grafana_linux.sh
    user: admin
    pass: prom-operator

Public exposure for the talk:
    ./expose/cloudflared.sh
EOF
