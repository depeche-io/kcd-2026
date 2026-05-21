---
theme: default
colorSchema: 'light'
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


---

# Who

<div class="grid grid-cols-2 gap-12 items-center h-[80%]">

<div class="flex flex-col items-center gap-4">
  <img :src="'/david-pech.jpg'" class="rounded-full w-40 h-40 object-cover ring-4 ring-blue-400 shadow-2xl" />
  <div class="text-3xl font-bold tracking-tight">David Pech</div>
  <div class="flex items-center gap-8 mt-2">
    <img :src="'/wrike-logo.svg'" class="h-12" />
    <img :src="'/kubestronaut.png'" class="h-20" />
  </div>
</div>

<div class="flex flex-col items-center gap-4">
  <img :src="'/petr-rais.jpg'" class="rounded-full w-40 h-40 object-cover ring-4 ring-blue-400 shadow-2xl" />
  <div class="text-3xl font-bold tracking-tight">Petr Rais</div>
  <div class="flex items-center gap-8 mt-2">
    <img :src="'/sluno-logo.svg'" class="h-12" />
  </div>
</div>

</div>

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

<div class="mt-2 grid grid-cols-2 gap-4 text-sm">

<div class="kcd-card">
  🔥 <strong>Burns fuel</strong> (jet, diesel)<br/>
  <code>liters × emission factor</code>
</div>

<div class="kcd-card">
  ⚡ <strong>Uses electricity</strong> (metro, train, <em>your pods</em>)<br/>
  <code>kWh × grid intensity (CZ ≈ 0.36 kg/kWh)</code>
</div>

</div>

<div class="mt-2 text-base">
  💡 One always-on 5 W pod ≈ <strong>one Ostrava→Prague train trip</strong> per year. Multiply by your replica count.
</div>

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
  Sources: Reuters · <a href="https://nltimes.nl/2022/03/31/facebooks-aggressive-uncompromising-lobbying-killed-zeewolde-data-center">NL Times</a> · <a href="https://www.datacenterdynamics.com/en/news/dutch-government-wont-sell-zeewolde-land-to-meta-hyperscale-data-center-development-moratorium-moves-forward/">DataCenterDynamics</a> · TD Cowen.
</div>


---
layout: default
---

# k0s on the Edge: Kubernetes that fits in your pocket 🥧

<div class="grid grid-cols-2 gap-8 mt-4 text-base">

<div>

**k0s** — single static binary, zero config
- No etcd to manage, no separate binaries
- Runs on **Raspberry Pi 4 · ARM64 · 2 GB RAM**
- `curl | sh` install, systemd service
- Same `kubectl` as anywhere else

**Rebuilt from git in minutes:**
- Wipe the Pi → reinstall k0s → profit
- ArgoCD re-syncs all workloads automatically
- No manual state to recover

</div>

<div>

<div class="kcd-card text-sm">
  <strong>What fits on a Raspberry Pi 4 (2 GB)?</strong><br/>
  &nbsp;k0s control+worker <strong>~150 MB</strong><br/>
  &nbsp;coredns ~20 MB · node-exporter ~15 MB<br/>
  &nbsp;kube-state-metrics ~40 MB · Kepler DS ~60 MB<br/>
  &nbsp;⇒ <strong>~285 MB observability+control</strong><br/>
  &nbsp;⇒ <strong>~1.7 GB free for your workloads</strong>
</div>

<div class="mt-4 text-sm opacity-80">
  k0s distro: <code>k0sproject.io</code> — CNCF member project, production-grade.
</div>

</div>

</div>


---
layout: default
---

# One HQ, N edge clusters — ArgoCD remote management 🏢

```
   git push ──▶ ┌──── 🏢 HQ cluster (ArgoCD) ────┐
                │  ApplicationSet → N clusters    │
                │  Prometheus scrapes all edges   │
                │  Grafana · Kepler dashboards    │
                └──┬──────────────────────────────┘
                   │ ArgoCD remote cluster (SA token)
         ┌─────────┼─────────┐
         ▼         ▼         ▼
   🥧 Pi site 1  🥧 Pi site 2  🥧 Pi site N
   k0s + workloads  k0s + workloads  k0s + workloads
```

<div class="grid grid-cols-2 gap-4 mt-2 text-sm">

<div>

**ArgoCD remote cluster feature**
- Register edge cluster with a ServiceAccount token
- HQ ArgoCD manages apps on the remote k0s node
- No ArgoCD agent on the edge — HQ reaches out
- `ApplicationSet` fans out one app to N clusters

</div>

<div>

**HQ does the heavy lifting**
- 1 ArgoCD ≈ 250 MB amortized across N sites
- HQ Prometheus scrapes edge via API-server proxy
- HQ can **suspend off-hours** (kube-green, scale-to-zero)
- 1 site or 1000 sites: **one git repo**

</div>

</div>


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
  An 8×H100 DGX node ≈ <strong>~10.2 kW</strong> — a small server room in one chassis.
</div>


---
layout: default
---

# NVIDIA H100 SXM 🤖

<div class="grid grid-cols-2 gap-8 mt-6 items-start">

<img :src="'/nvidia-h100.jpg'" class="w-full h-64 object-cover rounded-xl shadow-lg" />

<div class="flex flex-col gap-3">
  <div class="grid grid-cols-2 gap-3">
    <div class="kcd-card">
      <div class="text-2xl font-bold">700 W</div>
      <div class="text-sm opacity-80">TDP at full load</div>
    </div>
    <div class="kcd-card">
      <div class="text-2xl font-bold">~80 W</div>
      <div class="text-sm opacity-80">Idle</div>
    </div>
  </div>
  <div class="text-base flex flex-col gap-1 mt-1">
    <div>🧠 <strong>80 GB</strong> HBM3</div>
    <div>⚡ <strong>3.35 TB/s</strong> memory bandwidth</div>
    <div>🔢 <strong>3,958 TFLOPS</strong> FP16</div>
    <div>📅 Released 2022 — Hopper architecture</div>
  </div>
  <div class="kcd-card kcd-card-warn text-sm">
    ≈ <strong>100× Raspberry Pi 5</strong> power at load
  </div>
</div>

</div>

---
layout: default
---

# NVIDIA B200 🤖

<div class="grid grid-cols-2 gap-8 mt-6 items-start">

<img :src="'/nvidia-b200.jpg'" class="w-full h-64 object-cover rounded-xl shadow-lg" />

<div class="flex flex-col gap-3">
  <div class="grid grid-cols-2 gap-3">
    <div class="kcd-card">
      <div class="text-2xl font-bold">1,000 W</div>
      <div class="text-sm opacity-80">TDP at full load</div>
    </div>
    <div class="kcd-card">
      <div class="text-2xl font-bold">~150 W</div>
      <div class="text-sm opacity-80">Idle</div>
    </div>
  </div>
  <div class="text-base flex flex-col gap-1 mt-1">
    <div>🧠 <strong>192 GB</strong> HBM3e</div>
    <div>⚡ <strong>8 TB/s</strong> memory bandwidth</div>
    <div>🔢 <strong>~9 PFLOPS</strong> FP16</div>
    <div>📅 Released 2024 — Blackwell architecture</div>
  </div>
  <div class="kcd-card kcd-card-danger text-sm">
    1.4× more power than H100 · 2.3× the bandwidth
  </div>
</div>

</div>

---
layout: default
---

# NVIDIA DGX H100 — 8× H100 in one box 🏭

<div class="grid grid-cols-2 gap-8 mt-6 items-start">

<img :src="'/nvidia-dgx-h100.png'" class="w-full h-64 object-cover rounded-xl shadow-lg" />

<div class="flex flex-col gap-3">
  <div class="kcd-card kcd-card-danger">
    <div class="text-2xl font-bold">~10.2 kW</div>
    <div class="text-sm opacity-80">Full system TDP</div>
  </div>
  <div class="text-base flex flex-col gap-1 mt-1">
    <div>🤖 <strong>8× H100 SXM5</strong> GPUs</div>
    <div>🧠 <strong>640 GB</strong> total HBM3</div>
    <div>🔗 <strong>NVLink 4.0</strong> — 900 GB/s interconnect</div>
    <div>💾 <strong>2× 1.92 TB</strong> NVMe SSD</div>
    <div>⚡ Requires <strong>3-phase power</strong> supply</div>
  </div>
  <div class="kcd-card kcd-card-warn text-sm">
    A small server room in <strong>one 6U chassis</strong>.<br/>
    ~5× a typical rack's power budget — for a single node.
  </div>
</div>

</div>

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
- [*Green AI in Cloud Native*](https://www.youtube.com/watch?v=fznzH-gf9h8) — KubeCon EU 2025
- [*How Green is My OpenTelemetry Collector?*](https://www.youtube.com/watch?v=ea2CKLX5vEs) — KubeCon EU 2025
- [FinOps × GreenOps](https://www.youtube.com/watch?v=ubD4hg0cps8) — Sustainability Month Tokyo (Dec 2025)

</div>

</div>

<div class="mt-8 text-lg text-center">
  🔗 <code>tag-env-sustainability.cncf.io</code> — weekly open meetings.
</div>


---
layout: cover
class: text-center
---

# Demo time! 🌞🌬️


---
layout: default
---

# Carbon-aware HPA: the **solar + fan** demo 🌞🌬️💡

```
                                          ┌─────────────────────────────────┐
☀️ solar panel                            │         HQ cluster              │
      │ power                             │                                 │
      ▼                                   │  ┌────────────┐   ┌──────┐    │
┌─────────────┐──power──▶ 🔋 powerbank   │  │ Prometheus │──▶│ KEDA │    │
│ USB tester  │                           │  └─────┬──────┘   └──┬───┘    │
└──────┬──────┘                           │        │ scrape       │ scale  │
       │ data cable                       └────────┼─────────────┼────────┘
       ▼                                           │             │
┌─────────────────────────┐                       │             ▼
│      Raspberry Pi       │──expose metrics──────▶┘      🌬️ fan / 💡 LED
│  Python script (pyUSB)  │◀─────────────────────────────(GPIO on Pi)
└─────────────────────────┘
```

<div class="mt-4 text-base">
  USB tester measures solar watts → data cable to Pi → Python script reads USB tester &amp; exposes metrics → HQ Prometheus scrapes → KEDA scales the fan / LED belt pod on the Pi.
</div>

<div class="mt-3 text-base opacity-90">
  Silly hardware, real loop. Same control flow on a real grid:
  <strong>KEDA + carbon-aware-keda-operator</strong> reads
  <strong>WattTime / Electricity Maps</strong> and time-shifts batch jobs to greener hours.
</div>

<div class="kcd-source">
  Refs: <a href="https://github.com/Azure/carbon-aware-keda-operator"><code>Azure/carbon-aware-keda-operator</code></a> · Kubernetes WG-Batch · <a href="https://github.com/Green-Software-Foundation/carbon-aware-sdk">GSF Carbon Aware SDK</a>
</div>


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


---
layout: default
---

# Same VM, different region: `n4-standard-8` /year

<div class="text-sm opacity-80 mt-1">
  8 vCPU / 32 GB · ~80 W avg load · ~700 kWh/yr · × Google's published per-region grid intensity (2024).
</div>

<div class="mt-3 flex flex-col gap-1 text-sm">

<div class="grid grid-cols-[13rem_1fr_5rem] items-center gap-3">
  <div>🇫🇷 <code>europe-west9</code> (Paris)</div>
  <div class="h-5 rounded bg-emerald-500" style="width: 12%"></div>
  <div class="text-right font-bold">~55 kg</div>
</div>

<div class="grid grid-cols-[13rem_1fr_5rem] items-center gap-3">
  <div>🇫🇮 <code>europe-north1</code> (Finland)</div>
  <div class="h-5 rounded bg-emerald-400" style="width: 19%"></div>
  <div class="text-right font-bold">~89 kg</div>
</div>

<div class="grid grid-cols-[13rem_1fr_5rem] items-center gap-3">
  <div>🇧🇪 <code>europe-west1</code> (Belgium)</div>
  <div class="h-5 rounded bg-yellow-400" style="width: 25%"></div>
  <div class="text-right font-bold">~118 kg</div>
</div>

<div class="grid grid-cols-[13rem_1fr_5rem] items-center gap-3">
  <div>🇳🇱 <code>europe-west4</code> (Netherlands)</div>
  <div class="h-5 rounded bg-orange-500" style="width: 65%"></div>
  <div class="text-right font-bold">~301 kg</div>
</div>

<div class="grid grid-cols-[13rem_1fr_5rem] items-center gap-3">
  <div>🇺🇸 <code>us-central1</code> (Iowa)</div>
  <div class="h-5 rounded bg-orange-600" style="width: 82%"></div>
  <div class="text-right font-bold">~378 kg</div>
</div>

<div class="grid grid-cols-[13rem_1fr_5rem] items-center gap-3">
  <div>🇮🇳 <code>asia-south1</code> (Mumbai)</div>
  <div class="h-5 rounded bg-red-600" style="width: 100%"></div>
  <div class="text-right font-bold">~469 kg</div>
</div>

</div>

<div class="mt-3 kcd-card text-sm">
  ⚡ <strong>~8.5× spread</strong> for the <em>same</em> machine.
  europe-west9 ≈ Paris flight; asia-south1 ≈ <strong>10 Paris flights</strong> per VM/yr.
  Region selection is the cheapest single carbon decision your platform team can make.
</div>

<div class="kcd-source">
  Sources: <a href="https://cloud.google.com/sustainability/region-carbon">cloud.google.com/sustainability/region-carbon</a> (Google grid intensity 2024) · estimated 80 W avg, PUE 1.10.
</div>


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
  Source: <a href="https://aws.amazon.com/solutions/case-studies/pinterest-graviton-case-study/">AWS — Pinterest Graviton case study, 2024</a>.
</div>


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
    type="svg"
    data="https://github.com/depeche-io/kcd-2026/tree/main/feel-the-breeze"
    :margin="4"
    :dotsOptions="{ color: '#003a99' }"
    :backgroundOptions="{ color: '#f0f7ff' }"
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


---
layout: cover
class: text-center
---

# Backup Video 🎬

## If the Demo gods are not on our side
