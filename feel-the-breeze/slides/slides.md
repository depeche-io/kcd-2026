---
theme: default
colorSchema: 'dark'
title: 'Feel the Breeze'
info: |
  Feel the Breeze: The High-Energy, Fan-Powered Guide to Sustainable Kubernetes
  Kubernetes On Edge Day 2026 — David Pech & Petr Rais
layout: default
class: section title-slide
highlighter: shiki
lineNumbers: false
drawings:
  persist: false
transition: slide-left
mdc: true
addons:
  - slidev-addon-qrcode
fonts:
  provider: none
  sans: 'Inter'
  serif: 'Source Serif 4'
  mono: 'JetBrains Mono'
---

<div class="title-block">

# Feel the Breeze

## The High-Energy, Fan-Powered Guide<br/>to Sustainable Kubernetes

<div class="mt-9 text-lg leading-relaxed">
  <strong>David Pech</strong> &amp; <strong>Petr Rais</strong>
</div>
<div class="mt-4 text-sm text-[var(--kc-lavender)]">
  Kubernetes On Edge Day 2026<br/>
  Salt Lake City, Utah · November 9
</div>

</div>


---

# Who

<div class="grid grid-cols-2 gap-12 items-center h-[80%]">

<div class="flex flex-col items-center gap-4">
  <img :src="'/david-pech.jpg'" class="rounded-full w-40 h-40 object-cover ring-4 ring-[#B9C6E8] shadow-2xl" />
  <div class="text-3xl font-bold tracking-tight">David Pech</div>
  <div class="flex items-center gap-8 mt-2">
    <img :src="'/wrike-logo.svg'" class="h-12 speaker-logo" />
    <img :src="'/kubestronaut.png'" class="h-20" />
  </div>
</div>

<div class="flex flex-col items-center gap-4">
  <img :src="'/petr-rais.jpg'" class="rounded-full w-40 h-40 object-cover ring-4 ring-[#B9C6E8] shadow-2xl" />
  <div class="text-3xl font-bold tracking-tight">Petr Rais</div>
  <div class="flex items-center gap-8 mt-2">
    <img :src="'/sluno-logo.svg'" class="h-12 speaker-logo" />
  </div>
</div>

</div>

---
layout: default
---

# How did you get here?

<div class="slide-kicker">One-way to Salt Lake City · illustrative routes · per person</div>

<CO2Bar :rows="[
  { icon: '✈️', label: 'New York → SLC', distance: '~2,000 mi', kg: 258, display: '~258' },
  { icon: '🚗', label: 'Denver → SLC · solo driver', distance: '~520 mi', kg: 154.4, display: '~154' },
  { icon: '✈️', label: 'San Francisco → SLC', distance: '~600 mi', kg: 77.4, display: '~77' },
  { icon: '🚈', label: 'Airport → downtown · TRAX', distance: '~10 mi', kg: 0.93, display: '~0.9' },
  { icon: '🚶', label: 'Downtown hotel → venue', distance: '~1 mi', kg: 0, display: '0 direct' }
]" />

<div class="kcd-card kcd-card-bee mt-5 text-base">
  An illustrative <strong>5 W always-on pod</strong> uses 43.8 kWh/year.<br/>
  At Salt Lake City's grid factor: <strong>~25 kg CO₂e/year</strong>. Now count your replicas.
</div>

<div class="kcd-source">
  <a href="https://www.epa.gov/system/files/documents/2025-01/ghg-emission-factors-hub-2025.pdf">EPA 2025, Table 10</a>: travel bars show kg CO₂; rail uses a US average, not UTA measurements. Approximate distances; flights exclude non-CO₂ effects.<br/>
  Pod: assumed 5 W × 8,760 h × <a href="https://cloud.google.com/sustainability/region-carbon">568 gCO₂e/kWh (Google, 2025)</a>; IT energy only.
</div>

<!--
Travel calculations use EPA CO2 factors only, not the full CO2e factors:
2,000 passenger-mi × 0.129 = 258 kg; 600 × 0.129 = 77.4 kg.
520 vehicle-mi × 0.297 = 154.44 kg, allocated to one occupant.
10 passenger-mi × 0.093 = 0.93 kg; national transit rail average.
Distances are rounded teaching assumptions, not itinerary estimates.
The TRAX Green Line connects SLC airport to downtown (UTA airport travel guide).
Walking counts direct operational emissions only.
Pod power is a hypothetical allocation, not a measured idle-pod baseline.
43.8 kWh × 0.568 = 24.8784 kg CO2e. No facility PUE in this comparison.
-->


---
layout: default
---

# Even hyperscalers hit the wall

<div class="slide-kicker">The constraint is increasingly physical · IEA update, 2026</div>

<div class="grid grid-cols-3 gap-5 mt-7">
  <div class="kcd-card"><div class="stat">485 <small>TWh</small></div><div>Global data-centre electricity use in 2025</div></div>
  <div class="kcd-card kcd-card-bee"><div class="stat">950 <small>TWh</small></div><div>Projected for 2030<br/>~3% of global demand</div></div>
  <div class="kcd-card"><div class="stat">+17<small>%</small></div><div>Data-centre electricity demand growth in 2025</div></div>
</div>

<div class="grid grid-cols-2 gap-7 mt-7 text-base">
  <div><strong>Grid connections, transformers, permits.</strong><br/>IEA reports tighter bottlenecks and growing local opposition.</div>
  <div><strong>US developers are turning to onsite gas.</strong><br/>Reliable supply can require 30–70% more generation capacity than the data-centre load.</div>
</div>

<div class="kcd-card kcd-card-bee mt-6">Our platform lever: <strong>reduce wasted capacity and make suitable workloads flexible.</strong></div>

<div class="kcd-source">
  <a href="https://www.iea.org/reports/key-questions-on-energy-and-ai/executive-summary">IEA — Key Questions on Energy and AI (2026)</a> · 2030 values are projections, not measured consumption. CC BY 4.0.
</div>


---
layout: default
---

# Kubernetes that fits in your pocket

<div class="slide-kicker">k0s on a Raspberry Pi 4 · ARM64 · 2 GB RAM</div>

<div class="grid grid-cols-2 gap-9 mt-7 text-base">
<div>

### Small edge, familiar tools

- k0s runs the Kubernetes control plane + worker
- Same Kubernetes API and `kubectl`
- Argo CD at HQ manages the remote cluster
- Prometheus scrapes edge telemetry

</div>
<div>

### Rebuild from declared state

- Flash Ubuntu and apply cloud-init
- Install k0s and register the Pi at HQ
- Argo CD syncs the declared workloads
- Restore device credentials separately

</div>
</div>

<div class="kcd-card kcd-card-bee mt-8">
  Keep the edge lean: put <strong>Argo CD, Prometheus and Grafana at HQ</strong>.<br/>
  Measure the actual memory and power budget on your hardware.
</div>

<div class="kcd-source">Demo configuration: <a href="https://github.com/depeche-io/kcd-2026/tree/main/feel-the-breeze">our feel-the-breeze project repository</a> · <code>pi/</code> + <code>hq/</code></div>


---
layout: default
---

# One HQ, N edge clusters

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
- Central services amortized across N sites
- HQ Prometheus scrapes edge via API-server proxy
- Suspend eligible **workloads** off-hours
- 1 site or 1000 sites: **one git repo**

</div>

</div>


---
layout: default
---

# Project Kepler

<div class="slide-kicker">Kubernetes-based Efficient Power Level Exporter · CNCF Sandbox</div>

<div class="grid grid-cols-2 gap-8 mt-6 text-base">
<div>

### Current: v0.12.0 · Sep 22, 2026

- Hardware energy → workload attribution → Prometheus
- CPU-time attribution using **procfs + sysfs**
- RAPL; experimental hwmon, GPU and Redfish support
- No eBPF capability required in the current architecture

</div>
<div>

### What changed since the old deck?

- The eBPF/model-server design is **legacy (≤0.9)**
- v0.12 adds ARM64 images, hwmon fallback and MIG attribution via DCGM
- Per-pod watts are **attributed**, not a dedicated physical meter

</div>
</div>

<div class="kcd-card kcd-card-warn mt-5 text-base">
  <strong>This demo uses the older Helm chart 0.5.10.</strong> On our Pi, Kepler values are model estimates; the USB tester measures solar input. These are different signals.
</div>

<div class="kcd-source">
  <a href="https://github.com/sustainable-computing-io/kepler/releases/tag/v0.12.0">Kepler v0.12.0 release</a> · <a href="https://sustainable-computing.io/">Current documentation</a> · <a href="https://sustainable-computing.io/archive/">Legacy architecture</a> · verified November 4, 2026.
</div>

<!--
Do not silently upgrade the live demo to match this slide. Its chart and dashboard
use the older metric schema and the Pi lacks supported hardware energy counters.
The current architecture attributes measured active node power by CPU time;
it does not measure every pod independently or infer total facility consumption.
-->


---
layout: default
---

# Watts are a signal. Work is the denominator.

<div class="grid grid-cols-3 gap-5 mt-8 text-base">
  <div class="kcd-card"><div class="step">01 / MEASURE</div><strong>W → kWh</strong><p>Integrate power over time. State which hardware boundary your sensor covers.</p></div>
  <div class="kcd-card"><div class="step">02 / ATTRIBUTE</div><strong>Node → workload</strong><p>Label measured inputs and estimated shares. Keep idle power visible.</p></div>
  <div class="kcd-card kcd-card-bee"><div class="step">03 / COMPARE</div><strong>Energy per useful result</strong><p>Compare the same job, request volume and SLO before and after.</p></div>
</div>

<div class="formula mt-7">Operational emissions = kWh × grid intensity</div>
<div class="text-base mt-4">For a fuller view: <strong>SCI = (operational + embodied emissions) / unit of work.</strong></div>

<div class="kcd-source">
  <a href="https://sci.greensoftware.foundation/">Green Software Foundation — Software Carbon Intensity specification</a> · <a href="https://sustainable-computing.io/kepler/usage/power-attribution/">Kepler power attribution</a>.<br/>
  To reduce node baseline power, consolidate workloads and scale down infrastructure.
</div>

---
layout: default
---

# Move the work, keep the deadline

<div class="slide-kicker">A worked example · hypothetical grid signals, same completed job</div>

<div class="grid grid-cols-[1fr_auto_1fr] items-center gap-7 mt-7">
  <div class="kcd-card"><div class="step">RUN NOW</div><div class="stat">50 <small>kg CO₂e</small></div><div>100 kWh × 500 gCO₂e/kWh</div></div>
  <div class="text-4xl text-[var(--kc-bee)]">→</div>
  <div class="kcd-card kcd-card-ok"><div class="step">RUN IN A CLEANER WINDOW</div><div class="stat">10 <small>kg CO₂e</small></div><div>100 kWh × 100 gCO₂e/kWh</div></div>
</div>

<div class="mt-6 text-xl"><strong>80% less operational carbon</strong> in this example, with the same energy and output.</div>

<div class="grid grid-cols-2 gap-5 mt-5 text-base">
  <div><strong>Good candidates</strong><br/>Batch analytics, CI, media transcoding, non-urgent backups.</div>
  <div><strong>Keep the constraints explicit</strong><br/>Deadline, queue age, SLO, data locality and signal freshness.</div>
</div>

<div class="kcd-source">
  Illustrative arithmetic, not a measured saving. Account for restart, transfer and waiting overhead.<br/>
  <a href="https://github.com/Azure/carbon-aware-keda-operator">Carbon Aware KEDA Operator</a> can cap maximum replicas using an external carbon-intensity forecast; KEDA still determines demand.
</div>

---
layout: default
---

# CNCF Environmental Sustainability

<div class="slide-kicker">The former TAG now continues as a Technical Community Group (TCG)</div>

<div class="grid grid-cols-2 gap-9 mt-7 text-base">
<div>

### Join the community

- Energy and carbon metrics; tooling such as Kepler
- Share measurements, patterns and case studies
- Cloud Native Sustainability Month
- Slack: **#tcg-environmental-sustainability**

</div>
<div>

### Green Reviews: a new home

Now a subproject of **TAG Operational Resilience**.

Help CNCF projects assess their resource and energy footprint through structured, repeatable reviews.

</div>
</div>

<div class="kcd-card kcd-card-bee mt-7">Bring one repeatable experiment. Share the workload, hardware, method and results.</div>

<div class="kcd-source">
  <a href="https://contribute.cncf.io/community/tcgs/environmental-sustainability/">Environmental Sustainability TCG</a> · <a href="https://contribute.cncf.io/community/tags/operational-resilience/#green-reviews">Green Reviews / TAG Operational Resilience</a> · <a href="https://ocgroups.dev/cncf/group/env">Current meetings</a> · verified November 4, 2026.
</div>


---
layout: center
class: section text-center
---

# Demo time!


---
layout: default
---

# The solar + fan control loop

<div class="slide-kicker">A physical signal makes the scaling decision visible</div>

<div class="demo-flow mt-7">
  <div class="kcd-card"><div class="step">SUNLIGHT</div><strong>Solar panel</strong><div>↓ USB power</div><strong>FNB48P tester</strong></div>
  <div class="flow-arrow">→</div>
  <div class="kcd-card"><div class="step">RASPBERRY PI</div><strong>Python / pyUSB</strong><div>Measured solar watts</div><code>solar_generation_watts</code></div>
  <div class="flow-arrow">→</div>
  <div class="kcd-card"><div class="step">HQ CLUSTER</div><strong>Prometheus → KEDA</strong><div>Scale controller pods</div><div>↓ local LAN commands</div></div>
</div>

<div class="grid grid-cols-2 gap-6 mt-6 text-base">
  <div class="kcd-card kcd-card-bee"><strong>LED: follows solar availability</strong><br/>Controller scales 0 ↔ 1 with measured input power.</div>
  <div class="kcd-card"><strong>Fan: runs until blackout</strong><br/>Controller stays at 1 in sun/cloud; blackout scales it to 0.</div>
</div>

<div class="mt-5 text-base">A <strong>renewable-availability demo</strong>. A production carbon-aware loop needs a grid-intensity signal and workload constraints.</div>

<div class="kcd-source">Meter → Pi API → HQ Prometheus/KEDA → controller → Tuya over LAN. Solar input is measured; Kepler on this Pi is estimated.</div>


---
layout: default
---

# Key takeaways

<div class="grid grid-cols-1 gap-8 mt-12">

<div class="flex items-start gap-4">
  <div class="text-5xl">1️⃣</div>
  <div>
    <div class="text-2xl font-bold text-[var(--kc-bee)]">K8s at the small edge is mature.</div>
    <div class="text-base opacity-80 mt-1">k0s + ArgoCD-from-HQ + shared Prometheus = a real fleet pattern, not a toy.</div>
  </div>
</div>

<div class="flex items-start gap-4">
  <div class="text-5xl">2️⃣</div>
  <div>
    <div class="text-2xl font-bold text-[var(--kc-bee)]">Power is observable now.</div>
    <div class="text-base opacity-80 mt-1">Kepler attributes energy to workloads. Verify the sensor coverage and label estimates.</div>
  </div>
</div>

<div class="flex items-start gap-4">
  <div class="text-5xl">3️⃣</div>
  <div>
    <div class="text-2xl font-bold text-[var(--kc-bee)]">The next scaling axis is carbon.</div>
    <div class="text-base opacity-80 mt-1">Move flexible work to cleaner hours or regions, while meeting the same deadline and SLO.</div>
  </div>
</div>

</div>


---
layout: default
---

# Same VM, different region

<div class="slide-kicker"><code>n4-standard-8</code> / year · 8 vCPU, 32 GB · illustrative energy model</div>

<div class="grid grid-cols-[0.95fr_1.05fr] gap-6 items-center mt-5">
  <div><img :src="'/world-regions.svg'" alt="World map with six numbered Google Cloud region locations across six continents" class="w-full h-[11rem] object-contain"/><div class="text-xs opacity-70 text-center mt-2">Six continents · approximate region locations</div></div>
  <RegionCarbon />
</div>

<div class="kcd-card kcd-card-bee mt-5 text-base"><strong>~40× spread</strong> between Paris and Johannesburg under identical energy assumptions. Check latency, capacity and data residency before moving.</div>

<div class="kcd-source">
  <strong>Assumed</strong> 80 W IT × 8,760 h × PUE 1.10 = 770.88 kWh/year. Not measured N4 power.<br/>
  <a href="https://cloud.google.com/sustainability/region-carbon">Google region data, 2025</a>: location-based grid averages, not Google's CFE% or your billed footprint. Excludes embodied hardware, storage and network. Map: Natural Earth.
</div>


---
layout: default
---

# Try it this week

<div class="grid grid-cols-[1.25fr_0.75fr] gap-8 mt-6 text-base">
<div>

### 1. Start with one supported node

```bash
helm install kepler \
  oci://quay.io/sustainable_computing_io/charts/kepler \
  --namespace kepler --create-namespace
```

Check sensor support and the emitted metric names before building a dashboard. Pin chart and image versions after validation.

### 2. Pick one flexible workload

Record its energy, completed work and SLO. Test one cleaner time window or an eligible lower-carbon region.

</div>
<div>

### 3. Compare before / after

- kWh per completed job
- Operational CO₂e per job
- Runtime and deadline met
- Node idle time and baseline power

<div class="kcd-card kcd-card-bee mt-5">A repeatable measurement beats a hardware-spec comparison.</div>

</div>
</div>

<div class="kcd-source"><a href="https://sustainable-computing.io/">Kepler quick start</a> · This is the current upstream installation path; our Pi demo keeps its existing legacy chart.</div>


---
layout: default
---

# Thank you

<div class="mt-3 text-xl">Questions? Come <em>feel the breeze</em> on stage.</div>

<div class="grid grid-cols-[1fr_auto] gap-10 items-center mt-6">
<div class="text-left text-lg">
  <div><strong>David Pech</strong><br/><a href="https://github.com/depeche-io" class="text-base">github.com/depeche-io</a></div>
  <div class="mt-4"><strong>Petr Rais</strong><br/><a href="https://github.com/petrrais" class="text-base">github.com/petrrais</a></div>
  <div class="mt-7 text-sm text-[var(--kc-lavender)]">Kubernetes On Edge Day 2026<br/>Salt Lake City, Utah · November 9</div>
  <div class="mt-3 text-base text-[var(--kc-bee)]">#K8sEdgeDay · #FeelTheBreeze</div>
</div>
<div class="flex flex-col items-center mr-5">
  <QRCode :width="210" :height="210" type="svg"
    data="https://github.com/depeche-io/kcd-2026/tree/main/feel-the-breeze"
    :margin="6" :dotsOptions="{ color: '#113E82' }" :backgroundOptions="{ color: '#ffffff' }" />
  <div class="mt-3 text-sm">Demo repository + slides</div>
</div>
</div>


---
layout: center
class: section text-center
---

# Backup Video

## If the demo gods are not on our side
