---
theme: default
title: 'Feel the Breeze'
info: |
  Feel the Breeze: The High-Energy, Fan-Powered Guide to Sustainable Kubernetes
  KCD Czech-Slovak 2026 — David Pech & Petr Rais
class: text-center
highlighter: shiki
lineNumbers: false
drawings:
  persist: false
transition: slide-left
mdc: true
addons:
  - slidev-addon-qrcode
fonts:
  sans: 'Inter'
  mono: 'JetBrains Mono'
css: ./style.css
---

# Feel the Breeze 🌬️

## The High-Energy, Fan-Powered Guide to Sustainable Kubernetes

<div class="mt-12 text-lg opacity-90">
  <strong>David Pech</strong> — Kubernetes, ArgoCD, AWS, OCI, Postgres fan<br/>
  <strong>Petr Rais</strong> — Software Engineer & DevOps enthusiast
</div>

<div class="abs-bl m-6 text-sm opacity-75">
  KCD Czech-Slovak 2026 · Prague
</div>

<div class="abs-br m-6 text-sm opacity-75">
  #FeelTheBreeze
</div>

<!--
Welcome everyone. We're David and Petr. Today we're going to do something a little
unusual: we'll measure the carbon cost of YOUR commute, then the carbon cost of your
PODS, and finally we'll let a solar panel scale a Kubernetes deployment in real time
so the front row gets an actual breeze. Buckle up.
-->

---
layout: default
---

# How did you get here? 🚆 ✈️ 🚌

<CO2Bar :rows="[
  { icon: '✈️', label: 'Flight Bratislava → Prague', distance: '200 km',  kg: 47,   display: '30–47' },
  { icon: '🚌', label: 'Bus Brno → Prague',          distance: '210 km',  kg: 18.7, display: '18.7' },
  { icon: '🚆', label: 'Train Ostrava → Prague',     distance: '360 km',  kg: 12.7, display: '12.7' },
  { icon: '🚇', label: 'Metro Hl. nádraží → Dejvická (C+A)', distance: '4.5 km', kg: 0.18, display: '0.13–0.18' },
  { icon: '🚶', label: 'Walk Bratislava → FIT ČVUT',          distance: '330 km', kg: 0,    display: '~0' },
  { icon: '💡', label: '1 idle pod for a year (5 W avg, CZ grid)', distance: '5 W × 8760 h', kg: 15.8, display: '15.8' }
]" />

<div class="mt-4 grid grid-cols-2 gap-6 text-base">

<div class="kcd-card">
  🔥 <strong>Burns fuel</strong> (jet, diesel)<br/>
  <code>liters × emission factor</code>
</div>

<div class="kcd-card">
  ⚡ <strong>Uses electricity</strong> (metro, train, <em>your pods</em>)<br/>
  <code>kWh × grid intensity (CZ ≈ 0.36 kg/kWh)</code>
</div>

</div>

<div class="mt-3 text-lg">
  💡 One always-on 5 W pod ≈ <strong>one Ostrava→Prague train trip</strong> per year. Multiply by your replica count.
</div>

<div class="kcd-source">
  Sources: ICAO/ICCT, DEFRA 2024, EEA, Electricity Maps (CZ 2024 ~0.36 kg CO₂/kWh).
</div>

<!--
Quick show of hands — who flew, who took the train, who walked? Now look at the orange
bar in the middle: that's ONE always-on pod doing nothing for a year. It sits between
the bus and the train. Two formulas, one shared mental model: anything electric — your
metro ride, your pod — turns into kg CO₂ via grid intensity. Burn fuel directly, or
draw kWh from a grid that's some mix of coal/gas/nuclear/wind. Hold this slide in mind:
when we look at Kepler later, you already know how to translate watts into kg.
-->

---
layout: default
---

# Even hyperscalers hit the wall

**Meta cancelled its 200 MW Zeewolde campus (NL)** in early 2022:

- 166 ha of farmland
- ~1.4 TWh/yr power demand
- Dutch Senate motion against it
- Local + parliamentary opposition

**Netherlands hyperscale moratorium** still in force (≥70 MW / ≥10 ha).

**Microsoft froze ~1.5 GW** of self-built DCs globally in early 2025 (UK, AU, ND).

<div class="kcd-source">
  Sources: Reuters, NL Times, DataCenterDynamics, TD Cowen.
</div>

<!--
This slide is about scale. When even Meta gets sent home from the Netherlands, you know
the era of "just spin up another region" is over.
-->

---
layout: default
---

# Tiny clusters, one HQ, fully GitOps 🏭 → 🏢

```
   ┌────── 🏠 home / 🏭 factory / 📡 edge sites ──────┐        ┌──── 🏢 HQ cluster ─────┐
   │  k0s · single node · ARM/Pi · 512 MB RAM         │◄──SA──►│  ArgoCD                │
   │  workloads + node-exporter + kube-state + Kepler │        │  Prometheus + Grafana  │
   │  ── rebuilt from git in minutes ──               │  Prom  │  Kepler dashboards     │
   └──────────────────────────────────────────────────┘  scrape└────────────────────────┘
                                                                ▲
                                                     git push ──┘  (one repo, N sites)
```

<div class="grid grid-cols-2 gap-6 mt-4 text-base">

<div>

**The edge** — same `kubectl` everywhere
- 1 site or 1000 sites: **one git repo**
- Wipe a Pi → reinstall k0s → ArgoCD re-syncs everything
- No per-site Prometheus, no per-site ArgoCD

</div>

<div>

**HQ does the heavy lifting**
- 1 ArgoCD ≈ 250 MB amortized across N factories
- HQ Prom scrapes factory via API-server proxy
- HQ can **suspend off-hours** (kube-green, scale-to-zero)

</div>

</div>

<div class="mt-4 kcd-card text-sm">
  <strong>What fits in 512 MB on a Raspberry Pi?</strong>
  &nbsp;k0s control+worker <strong>~150 MB</strong> · coredns ~20 MB · node-exporter ~15 MB · kube-state-metrics ~40 MB · Kepler DS ~60 MB
  &nbsp;⇒ <strong>~285 MB observability+control</strong>, <strong>~225 MB free for your app</strong>.
</div>

<div class="kcd-source">
  Files: <code>factory/lima-k0s.yaml</code> · <code>hq/bootstrap-argocd.sh</code> · <code>hq/gitops/apps/</code>
</div>

<!--
The whole story in one slide: tiny single-node Kubernetes (k0s, one binary, ~150 MB)
running anywhere — your home lab, a factory floor, a retail back-office, a Pi taped
under a desk. Each site is rebuildable from git in minutes; ArgoCD on HQ syncs it.
HQ centralises ArgoCD, Prometheus, Grafana, Kepler dashboards — so you pay the
control-plane RAM once, not N times. And HQ doesn't even need to be on 24/7.
The RAM table is the answer to "is k8s overkill on a Pi?" — no, you have ~225 MB
left for the actual workload after a full observability stack.
-->

---
layout: two-cols
---

# Project Kepler 🔌

**K**ubernetes-based **E**fficient **P**ower **L**evel **E**xporter

eBPF + RAPL/hwmon + ML model
→ **per-pod, per-container, per-process watts**

- 🟢 CNCF **Sandbox** (since May 2023)
- 📦 Latest stable: **v0.11.4** (Feb 2025)
- 🔗 `github.com/sustainable-computing-io/kepler`

**2025 highlights:**
- GPU power (NVIDIA NVML)
- Redfish BMC fallback
- Kubelet polling rewrite
- Native Grafana Labs integration

<div class="mt-4 text-base italic opacity-80">
  "If it's not eBPF, is it even Cloud Native?"
</div>

::right::

### Where the watts go — 2025 ballpark

<div class="text-sm grid grid-cols-[1fr_4rem_6rem] gap-x-3 gap-y-1 items-baseline">

<div class="font-semibold opacity-70">Component</div>
<div class="font-semibold opacity-70 text-right">Idle</div>
<div class="font-semibold opacity-70 text-right">Load</div>

<div>🧠 Server CPU (32c Xeon/EPYC)</div><div class="text-right">~40 W</div><div class="text-right font-bold">250–350 W</div>
<div>💻 Desktop CPU (i9 / Ryzen 9)</div><div class="text-right">~15 W</div><div class="text-right font-bold">125–250 W</div>
<div>🥧 Raspberry Pi 5 / ARM SoC</div><div class="text-right">~2 W</div><div class="text-right font-bold">8–12 W</div>
<div>💾 32 GB DDR5 ECC (per stick)</div><div class="text-right">~3 W</div><div class="text-right">~6 W</div>
<div>💿 Consumer NVMe SSD</div><div class="text-right">~1 W</div><div class="text-right">5–8 W</div>
<div>💿 Enterprise NVMe (U.2)</div><div class="text-right">~5 W</div><div class="text-right">10–25 W</div>
<div>🎮 Gaming GPU (RTX 4090)</div><div class="text-right">~15 W</div><div class="text-right font-bold">350–450 W</div>
<div>🤖 AI GPU (NVIDIA H100 SXM)</div><div class="text-right">~80 W</div><div class="text-right font-bold">~700 W</div>
<div>🤖 AI GPU (NVIDIA B200)</div><div class="text-right">~150 W</div><div class="text-right font-bold">~1000 W</div>

</div>

<div class="mt-3 kcd-card text-sm">
  ⚡ One H100 ≈ <strong>~100 Raspberry Pi 5s</strong> flat out.
  An 8×H100 DGX node ≈ <strong>~5.6 kW</strong> — a small server room in one chassis.
</div>

<!--
Kepler reads hardware power counters via eBPF and attributes them per-pod. RAPL gives
you the raw socket joules; the ML model splits them across containers using utilization
ratios. The table on the right is the mental model: CPUs and RAM are tens to a few
hundred watts; gaming GPUs blow past CPUs; datacenter AI accelerators are in a different
universe. When someone says "we're moving to GPU inference", that's the bill.
-->

---
layout: default
---

# CNCF TAG Environmental Sustainability 🌱

<div class="grid grid-cols-2 gap-10 mt-8">

<div>

### 🟢 Green Reviews
Public, per-project sustainability audits.
Falco · KubeVirt · OpenTelemetry · …
**You maintain a CNCF project? Request one.**

### 📊 Cloud Native Sustainability Landscape
The map of who's doing what.

</div>

<div>

### 🎤 Recent talks worth watching
- *Green AI in Cloud Native* — KubeCon EU 2025
- *How Green is My OpenTelemetry Collector?* — KubeCon EU 2025
- FinOps × GreenOps — Sustainability Month Tokyo (Dec 2025)

</div>

</div>

<div class="mt-8 text-lg text-center">
  🔗 <code>tag-env-sustainability.cncf.io</code> — weekly open meetings.
</div>

<!--
SIG Sustainability got renamed to TAG Environmental Sustainability. The Green Reviews
working group is the most concrete output — they go project by project (Falco,
KubeVirt, etc.) and produce a public sustainability report. If you maintain a CNCF
project, you can request one.
-->

---
layout: two-cols
---

# Live: Kepler watts on real pods

<KeplerLive url="" fallback="/kepler-screenshot.png" />

::right::

**Speaker checklist:**

- [ ] Show watts/pod on `factory` cluster
- [ ] `kepler_container_joules_total` ramping
- [ ] Apply `stress-ng` load
- [ ] Watch the line jump
- [ ] Translate to gCO₂/h using
      Czech grid factor: **~0.36 kg CO₂/kWh**

<div class="mt-4 text-sm opacity-75">
  Backup screenshot under <code>public/kepler-screenshot.png</code> if the cloudflared tunnel drops.
</div>

<div class="kcd-source">
  Grid intensity: ENTSO-E / Electricity Maps, CZ 2024 average.
</div>

<!--
This is the demo slide. Switch to the Grafana tab. Show the Kepler dashboard. Pick one
pod. Apply load with stress-ng. Watch the watts climb. Then do the math live: 5 W
continuous × 24 h × 365 = 44 kWh/yr × 0.36 kg CO₂/kWh = 16 kg CO₂/yr per pod. Then
multiply by 1000 pods. That's the moment people get it.
-->

---
layout: default
---

# Carbon-aware HPA: **solar + fan + LED** demo 🌞🌬️💡

```
┌───────────────┐   ┌──────────────┐   ┌──────────┐   ┌────┐   ┌───────────────┐
│ Simulated sun │──▶│ Pi REST API  │──▶│Prometheus│──▶│KEDA│──▶│ LED controller│
│ /sun /cloud   │   │ /metrics     │   │          │   │HPA │   │ replicas 0..1 │
└───────────────┘   └──────────────┘   └──────────┘   └────┘   └───────────────┘
                              │
                              ├──────────────▶ fan-controller pod (always 1)
                              │                 lifecycle: /vetrak/on|off
                              └──────────────▶ led-controller pod
                                                lifecycle: /led/on|off
```

<div class="mt-6 text-lg">
  Higher simulated solar power → HPA starts LED controller pod → LED strip turns on.
  Low solar power → pod scales to zero → LED turns off.
</div>

<div class="mt-4 text-base opacity-90">
  Same principle for real grids:
  <strong>KEDA + carbon-aware-keda-operator</strong> reads
  <strong>WattTime / Electricity Maps</strong> and shifts work to greener hours.
</div>

<div class="kcd-source">
  Refs: <code>github.com/Azure/carbon-aware-keda-operator</code> · Kubernetes WG-Batch · Green Software Foundation Carbon Aware SDK
</div>

<!--
This is the clean loop slide: /sun pushes solar_generation_watts up, KEDA creates an HPA,
LED controller scales from 0 to 1 and calls /led/on on the Pi. /cloud does the opposite.
Fan controller is separated in its own pod so the audience sees two independent actuators.
Then tie it back to real carbon-aware scheduling with grid APIs.
-->

---
layout: default
---

# Key takeaways

<div class="grid grid-cols-1 gap-8 mt-12">

<div class="flex items-start gap-4">
  <div class="text-5xl">1️⃣</div>
  <div>
    <div class="text-2xl font-bold text-[var(--kcd-blue)]">K8s at the small edge is mature.</div>
    <div class="text-base opacity-80 mt-1">k0s + ArgoCD-from-HQ + shared Prometheus = a real fleet pattern, not a toy.</div>
  </div>
</div>

<div class="flex items-start gap-4">
  <div class="text-5xl">2️⃣</div>
  <div>
    <div class="text-2xl font-bold text-[var(--kcd-blue)]">Power is observable now.</div>
    <div class="text-base opacity-80 mt-1">Kepler turns watts-per-pod from "trust the cloud bill" into a Prometheus metric you can alert on.</div>
  </div>
</div>

<div class="flex items-start gap-4">
  <div class="text-5xl">3️⃣</div>
  <div>
    <div class="text-2xl font-bold text-[var(--kcd-blue)]">The next scaling axis is carbon.</div>
    <div class="text-base opacity-80 mt-1">HPA on CPU is table stakes. The win is scaling on grid intensity.</div>
  </div>
</div>

</div>

<!--
Three things. Read them. Pause. Move on. Don't over-explain the takeaway slide.
-->

---
layout: default
---

# Same VM, different region: `n4-standard-8` for a year

<div class="text-base opacity-80 mt-2">
  8 vCPU / 32 GB · ~80 W avg load · ~700 kWh/yr · × Google's published per-region grid intensity (2024).
</div>

<div class="mt-6 flex flex-col gap-2">

<div class="grid grid-cols-[14rem_1fr_5rem] items-center gap-3">
  <div>🇫🇷 <code>europe-west9</code> (Paris)</div>
  <div class="h-6 rounded bg-emerald-500" style="width: 12%"></div>
  <div class="text-right font-bold">~55 kg</div>
</div>

<div class="grid grid-cols-[14rem_1fr_5rem] items-center gap-3">
  <div>🇫🇮 <code>europe-north1</code> (Finland)</div>
  <div class="h-6 rounded bg-emerald-400" style="width: 19%"></div>
  <div class="text-right font-bold">~89 kg</div>
</div>

<div class="grid grid-cols-[14rem_1fr_5rem] items-center gap-3">
  <div>🇧🇪 <code>europe-west1</code> (Belgium)</div>
  <div class="h-6 rounded bg-yellow-400" style="width: 25%"></div>
  <div class="text-right font-bold">~118 kg</div>
</div>

<div class="grid grid-cols-[14rem_1fr_5rem] items-center gap-3">
  <div>🇳🇱 <code>europe-west4</code> (Netherlands)</div>
  <div class="h-6 rounded bg-orange-500" style="width: 65%"></div>
  <div class="text-right font-bold">~301 kg</div>
</div>

<div class="grid grid-cols-[14rem_1fr_5rem] items-center gap-3">
  <div>🇺🇸 <code>us-central1</code> (Iowa)</div>
  <div class="h-6 rounded bg-orange-600" style="width: 82%"></div>
  <div class="text-right font-bold">~378 kg</div>
</div>

<div class="grid grid-cols-[14rem_1fr_5rem] items-center gap-3">
  <div>🇮🇳 <code>asia-south1</code> (Mumbai)</div>
  <div class="h-6 rounded bg-red-600" style="width: 100%"></div>
  <div class="text-right font-bold">~469 kg</div>
</div>

</div>

<div class="mt-6 kcd-card text-base">
  ⚡ <strong>~8.5× spread</strong> for the <em>same</em> machine.
  europe-west9 ≈ Paris flight; asia-south1 ≈ <strong>10 Paris flights</strong> per VM/yr.
  &nbsp;Region selection is the cheapest single carbon decision your platform team can make.
</div>

<div class="kcd-source">
  Sources: cloud.google.com/sustainability/region-carbon (Google grid intensity 2024) · estimated 80 W avg, PUE 1.10.
</div>

<!--
This is the slide that closes the loop with the takeaways. We just told them the next
scaling axis is carbon. Here's what that means in dollars and grams: the SAME n4 VM —
same CPU, same RAM, same workload — emits 8.5× more in Mumbai than in Paris. If your
batch jobs don't care where they run, region scheduling is the single highest-leverage
change you can make. No code change, no architecture change, just a placement
constraint in your IaC.
-->

---
layout: default
---

# Try it this week

**1. Install Kepler in your existing cluster**

```bash
helm repo add kepler \
  https://sustainable-computing-io.github.io/kepler-helm-chart
helm install kepler kepler/kepler -n kepler --create-namespace
```

**2. Open your cloud's carbon dashboard**

- ☁️ GCP — Carbon Footprint console
- ☁️ AWS — Customer Carbon Footprint Tool
- ☁️ Azure — Emissions Impact Dashboard

**3. Pick one CPU-family swap at your next FinOps review**

> Pinterest cut media-transcoding carbon **62%** by moving x86 → AWS Graviton.

<div class="kcd-source">
  Source: AWS Sustainability blog, 2024.
</div>

<!--
The ask is small: install Kepler. It's one Helm command, it runs as a DaemonSet, it
scrapes via ServiceMonitor. You will know within an hour which of your pods is the
energy hog. Then go pick one CPU-family swap during your next FinOps review and you've
done more for sustainability than 90% of the industry.
-->

---
layout: cover
class: text-center
---

# Thank you 🌬️

<div class="mt-4 text-xl">
  Questions? Come <em>feel the breeze</em> on stage.
</div>

<div class="grid grid-cols-2 gap-8 items-center mt-10">

<div class="text-left text-lg">
  <div class="opacity-90">
    <strong>David Pech</strong><br/>
    <span class="text-base font-mono opacity-80">github.com/depeche-io</span>
  </div>
  <div class="mt-4 opacity-90">
    <strong>Petr Rais</strong><br/>
    <span class="text-base font-mono opacity-80">github.com/petrrais</span>
  </div>
</div>

<div class="flex flex-col items-center">
  <QRCode
    :width="220"
    :height="220"
    value="https://github.com/depeche-io/kcd-2026/tree/main/feel-the-breeze"
    render-as="svg"
    type="image/png"
    :margin="1"
    :color="{ dark: '#ffffff', light: '#003a99' }"
  />
  <div class="mt-3 text-sm font-mono opacity-90">
    github.com/depeche-io/kcd-2026
  </div>
  <div class="mt-1 text-xs opacity-75">Repo + slides</div>
</div>

</div>

<div class="abs-bl m-6 text-sm opacity-75">
  KCD Czech-Slovak 2026 · #FeelTheBreeze · #KCDCzechSlovak2026
</div>

<div class="abs-br m-6 text-sm opacity-75">
  CNCF TAG Environmental Sustainability 🌱
</div>

<!--
Thank you! We have time for questions. Also — the solar panel and fan are still set up.
Come find us in the hallway track and we'll let you scale a deployment with a
flashlight.
-->
