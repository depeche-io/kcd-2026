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

### Solar simulation mode (no physical panel)

For rehearsals without real PV hardware:

```bash
# switch simulated solar production
./pi/solar-sim.sh sun
./pi/solar-sim.sh cloud
./pi/solar-sim.sh blackout   # cloud + turn off LED and fan
./pi/solar-sim.sh recover    # sun + turn fan back on

# run 3 demo cycles: 15s sun, 15s cloud
./pi/solar-sim.sh pulse 3 15 15
```

On HQ this drives two controller pods in `default` namespace:

* `smart-vetrak-controller` (fan) — KEDA/HPA scales `1` in `sun/cloud`, `0` in `blackout`
* `smart-led-controller` (LED strip) — KEDA/HPA scales `0..1` from `solar_generation_watts`

Grafana dashboard for this loop is provisioned from:

* `hq/manifests/grafana-solar-demo-dashboard.yaml`
* Dashboard title: **Solar Control Loop Demo**

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
slides/
  package.json               Slidev deps + scripts (dev / build / export)
  slides.md                  The 12-slide deck (1 intro + 10 + 1 outro)
  style.css                  CNCF-blue overrides on top of @slidev/theme-default
  components/                Custom Vue components used in the deck
    CO2Bar.vue               Horizontal bar chart for the transport-CO2 slide
    KeplerLive.vue           Iframe wrapper around the live Grafana Kepler dashboard
  public/                    Static assets — drop logos + backup screenshot here
docs/
  demo-runbook.md            Operator checklist for live demo and recovery steps
```

## Slides

The talk's slide deck lives in `slides/` and is built with [Slidev](https://sli.dev).

### Develop / preview

```bash
cd slides
npm install        # one-time; pulls @slidev/cli, default theme, qrcode addon
npm run dev        # opens http://localhost:3030 with hot-reload
```

Press `p` for presenter mode (speaker notes on a second monitor), `o` for overview,
`d` to draw on the slide.

### Build a static bundle

```bash
cd slides
npm run build      # outputs slides/dist/, deployable on any static host
```

### Export to PDF (offline fallback for the conference)

```bash
cd slides
npm run export     # produces slides-export.pdf
# or
npm run export:pdf # produces feel-the-breeze.pdf
```

PDF export needs Playwright Chromium under the hood — Slidev installs it on first run.

### Editing the deck

* All 12 slides live in a single file: `slides/slides.md` (one slide per `---`-separated block).
* The chart on slide 2 (CO₂ per transport mode) is data-driven via `CO2Bar.vue` —
  edit the `:rows="[...]"` array in the slide to change values.
* The live Grafana iframe on slide 8 takes a `url` prop in `KeplerLive.vue` — set it
  to the cloudflared URL emitted by `./expose/cloudflared.sh` before going on stage,
  and drop a backup PNG at `slides/public/kepler-screenshot.png`.
* QR code on slide 11 is rendered at build time by `slidev-addon-qrcode` — just
  edit the `value="..."` prop in `slides.md` to change the target URL.
* Brand colors come from `slides/style.css` (`--kcd-blue: #0086FF`).

### Pre-talk checklist

0. **Disable corporate VPN/firewall** before the demo — the TLS-intercepting proxy
   blocks ArgoCD's Helm chart fetches. Re-enable after the talk.

1. Drop logos into `slides/public/` (see `slides/public/.placeholder` for the list).
2. Update the GitHub repo URL in slide 11's `<QRCode value="...">` and the outro slide.
3. Bring the cloudflared Grafana URL up before the demo and paste it into
   `<KeplerLive url="...">` on slide 8.
4. `npm run export:pdf` and stash `feel-the-breeze.pdf` on a USB stick — projector
   surprises happen.
