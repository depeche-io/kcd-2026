# Feel the Breeze: The High-Energy, Fan-Powered Guide to Sustainable Kubernetes

Standard HPA is so totally out now. It scales on CPU but lacks synergy. It doesn’t know if your nodes are sipping clean wind or chugging dirty coal. It’s time to stop "shifting left" and start shifting to the sun!

In this carbon-critical session, we’re ditching boring metrics for Project Kepler. Using eBPF magic—because if it’s not eBPF, is it even Cloud Native?—we’ll expose the raw power consumption of your pods in real-time.

To ground the hype, we’re bringing a physical Solar Panel, lights and a Fan-as-a-Service on stage. Watch the replicas scale to peak intensity the moment our "sun" hits the panel, while industrial fans translate that clean energy into a literal breeze for the front row.

Beyond the hype, come learn how individual pods contribute to your cluster's energy footprint and how to accurately measure it. We’ll showcase a real-time demo of carbon-aware scaling with a few gadgets.


https://kcd-czech-slovak-2026.sessionize.com/session/1196568


# KCD 2026-1 — two-cluster demo

Live demo of two Kubernetes clusters running on a single MacBook:

| Cluster   | Where                          | What runs there                                  |
|-----------|--------------------------------|--------------------------------------------------|
| `factory` | Lima VM, k0s single-node       | Workloads + node-exporter + kube-state-metrics   |
| `hq`      | k3d (k3s in Docker)            | ArgoCD (autopilot) + kube-prometheus-stack + kepler |

ArgoCD on `hq` controls `factory` over the network using a service-account token,
and HQ Prometheus scrapes `factory` workload metrics through the factory API
server's proxy endpoint.

```
            ┌──────────────── macOS host ────────────────┐
            │                                            │
            │   ┌── Lima VM ──┐    ┌──── k3d ─────┐      │
            │   │  k0s        │◄──►│  ArgoCD      │      │
            │   │  factory    │    │  Prometheus  │      │
            │   │             │    │  Kepler      │      │
            │   └─────────────┘    └──────┬───────┘      │
            │                             │              │
            └─────────────────────────────┼──────────────┘
                                          │
                                  cloudflared tunnel
                                          │
                                          ▼
                                   audience browser
```

## Prerequisites

```bash
# Already in the devbox profile:
#   lima, kubectl, helm, argocd, argocd-autopilot

brew install k3d cloudflared
```

A GitHub repo (empty) for the GitOps state. Create one and a fine-grained PAT
with read/write to that repo, then:

```bash
cp .env.example .env
$EDITOR .env       # fill in GIT_REPO + GIT_TOKEN
set -a; source .env; set +a
```

## Run order

```bash
# 1. factory cluster (Lima VM with k0s, ~3 min)
./factory/up.sh

# 2. HQ cluster (k3d + ArgoCD + apps via GitOps, ~3 min)
./hq/up.sh
./hq/bootstrap-argocd.sh

# 3. expose Grafana publicly for the talk
./expose/cloudflared.sh
```

## Tear down

```bash
./hq/down.sh
./factory/down.sh
```

## During the talk

* `kubectl --kubeconfig=./factory.kubeconfig get nodes` — show factory.
* `kubectl --context=k3d-hq get applications -n argocd` — show HQ apps.
* Open the cloudflared URL → Grafana → "Kubernetes / Compute Resources / Cluster"
  dashboard with the `cluster` label set to `factory` to show cross-cluster scrape.
* Open the Kepler dashboard to show power per pod on HQ.

## Files

```
factory/
  lima-k0s.yaml              Lima template (Ubuntu + k0s + cloud-init)
  up.sh / down.sh            Create / destroy the VM
  manifests/
    hq-controller-sa.yaml    ServiceAccount + cluster-admin binding for HQ
    exporters.yaml           node-exporter + kube-state-metrics on factory
hq/
  up.sh / down.sh            Start / stop k3d cluster
  bootstrap-argocd.sh        argocd-autopilot bootstrap + push apps + register factory
  gitops/                    Files copied into the GitOps repo
    apps/
      kube-prometheus-stack/
      kepler/
expose/
  cloudflared.sh             Quick tunnel to Grafana
```
