# Feel the Breeze — Kubernetes On Edge Day 2026

Editable Slidev source: `slides.md`. Deliverable: `feel-the-breeze.pdf`.
The deck has **17 slides: 16 main slides and 1 backup-video slide**.
The presentation is in English for Kubernetes On Edge Day in Salt Lake City,
November 9, 2026. The event hashtag is **#K8sEdgeDay**; see the
[official event page](https://events.linuxfoundation.org/kubecon-cloudnativecon-north-america/co-located-events/kubernetes-on-edge-day/).

## Speaker scripts

- [English speaker script](speaker-notes.en.md)
- [Česká řeč k prezentaci](speaker-notes.cs.md)

Both scripts follow the current 17-slide order. They include a spoken narrative
and transitions, with separate introductions for David and Petr. Slides 11 and 12
have no prepared narration; slide 17 has an optional backup-video introduction.
Allow approximately 13–16 minutes for the main script in either language, plus
the live demo, audience interaction and questions. These are separate rehearsal
documents; they do not add slides to the PDF.

## Build and export

Use **Node.js 22.12+** (Node 22.23.4 was used for this export). The existing
lockfile includes dependencies that do not support the system's Node 20.18.

```bash
cd feel-the-breeze/slides
npm ci
npm run dev
npm run build
npm run export:pdf
```

PDF export requires Playwright Chromium. If it is missing:

```bash
npx playwright install chromium
```

`style.css`, `slide-bottom.vue`, and `public/theme/content-bg.jpg` adapt the supplied
`kubecon-2026-autoscaling-challenge-main/slides` style for Kubernetes On Edge Day.
Section slides use `public/theme/edge-day-logo.svg`, downloaded from the
[official event logo](https://events.linuxfoundation.org/wp-content/uploads/2024/05/K8ED_North-America_400x275-Logo-Color.svg)
and displayed on a white badge. The previous main-conference logo background is no longer used.
Fonts are bundled in
`public/fonts/`, with their SIL Open Font Licenses; slides do not fetch web fonts.
The QR codes retain the real demo repository URL. Video playback needs internet;
prepare a local recording separately for a fully offline talk.

## Data and assumptions

Checked **November 4, 2026**. Source links also appear on the relevant slides.

### Travel to Salt Lake City

[US EPA GHG Emission Factors Hub, January 2025, Table 10](https://www.epa.gov/system/files/documents/2025-01/ghg-emission-factors-hub-2025.pdf)
was the latest EPA edition listed on the [Hub](https://www.epa.gov/climateleadership/ghg-emission-factors-hub)
when checked. Travel bars use **CO₂**, not the full CO₂e factors or aviation's
non-CO₂ effects. Distances are rounded illustrative assumptions, one-way:

| Example | Assumed distance | CO₂ factor | Result |
| --- | ---: | ---: | ---: |
| New York → SLC flight | 2,000 passenger-mi | 0.129 kg/passenger-mi | 258 kg |
| Denver → SLC, solo driver | 520 vehicle-mi | 0.297 kg/vehicle-mi | 154.44 kg |
| San Francisco → SLC flight | 600 passenger-mi | 0.129 kg/passenger-mi | 77.4 kg |
| Airport → downtown, transit rail | 10 passenger-mi | 0.093 kg/passenger-mi | 0.93 kg |

The rail factor is a US average, **not measured UTA/TRAX emissions**.
[UTA confirms the airport's TRAX Green Line connection](https://wp.rideuta.com/Rider-Tools/Plan-Your-Trip-With-UTA/Airport-Travel).
Walking is zero direct operational emissions only.

The pod comparison is hypothetical: `0.005 kW × 8,760 h = 43.8 kWh`;
`43.8 × 0.568 = 24.8784 kg CO₂e/year`. It excludes facility overhead.
Five watts is an assumed workload allocation, not a measured idle-pod baseline.

### Hyperscaler constraints

[IEA, Key Questions on Energy and AI (2026), executive summary](https://www.iea.org/reports/key-questions-on-energy-and-ai/executive-summary)
updates the old Zeewolde / Microsoft anecdotes. It reports 485 TWh in 2025,
17% annual growth and a 950 TWh central projection for 2030. It also describes
grid and equipment bottlenecks and the capacity overhead of reliable onsite gas
supply. Forecasts are labelled explicitly. Attribution: IEA, 2026, CC BY 4.0.

### Kepler and the CNCF community

- [Kepler v0.12.0](https://github.com/sustainable-computing-io/kepler/releases/tag/v0.12.0)
  was published September 22, 2026; latest release when checked.
- [Current Kepler documentation](https://sustainable-computing.io/) and
  [attribution guide](https://sustainable-computing.io/kepler/usage/power-attribution/)
  describe hardware input and CPU-time attribution. The
  [eBPF / model-server documentation is legacy](https://sustainable-computing.io/archive/).
- **Do not upgrade the live demo just to match the upstream slide.** The checked-in
  Pi Argo CD Application pins chart **0.5.10**, with its older metrics/dashboard.
  On this Pi, Kepler's workload values are model estimates. The FNB48P measures
  solar input; it does not meter each pod or the entire Pi.
- The former TAG continues as the
  [Environmental Sustainability TCG](https://contribute.cncf.io/community/tcgs/environmental-sustainability/).
  Green Reviews is under
  [TAG Operational Resilience](https://contribute.cncf.io/community/tags/operational-resilience/#green-reviews).
  The slide links to the current group/calendar rather than promising weekly meetings.

### Regional VM comparison

[Google's region-carbon page, 2025 data](https://cloud.google.com/sustainability/region-carbon)
provides **location-based annual grid intensities**, distinct from Google's CFE%.
`RegionCarbon.vue` contains the input factors and derives the displayed values:

`0.080 kW × 8,760 h × 1.10 PUE = 770.88 kWh/year`.

| Region | Grid gCO₂e/kWh | Modelled kgCO₂e/year |
| --- | ---: | ---: |
| Paris / europe-west9 | 16 | 12 |
| São Paulo / southamerica-east1 | 73 | 56 |
| Sydney / australia-southeast1 | 468 | 361 |
| Salt Lake City / us-west3 | 568 | 438 |
| Mumbai / asia-south1 | 598 | 461 |
| Johannesburg / africa-south1 | 641 | 494 |

The 80 W allocation and PUE 1.10 are teaching assumptions, **not measured N4 power**.
This isolates the grid factor; it does not estimate the customer's reported cloud
footprint. Storage, networking and embodied hardware emissions are excluded.
The ratio is `641 / 16 ≈ 40.1`. N4 availability was checked against Google's
[regions and zones](https://docs.cloud.google.com/compute/docs/regions-zones).

`public/world-regions.svg` shows one region per inhabited continent on a world
map (Antarctica omitted), with approximate locations and country outlines from [Natural Earth, public-domain 1:110m boundaries](https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_110m_admin_0_countries.geojson).
The numbered markers correspond to the comparison rows; they are not exact
facility addresses. The map is a local SVG, with no tile-server dependency.

## Content choices and presenter notes

Three NVIDIA product/specification slides were replaced by two practical slides:

1. **Watts are a signal. Work is the denominator.** Measurement → attribution →
   energy and carbon per useful result. Based on the
   [GSF SCI specification](https://sci.greensoftware.foundation/).
2. **Move the work, keep the deadline.** A clearly hypothetical 100 kWh job at
   500 vs 100 gCO₂e/kWh, with constraints on deadlines, queue age and SLOs.
   [Carbon Aware KEDA Operator](https://github.com/Azure/carbon-aware-keda-operator)
   changes the replica ceiling using externally supplied carbon forecasts;
   it does not itself replace KEDA's demand calculation.

No extra main slides are needed. If a more technical audience needs PromQL,
replace the second example with one before/after benchmark from the live demo
once measured, including its hardware boundary and completed work. Do not present
hypothetical arithmetic as a measured saving.

The live-demo diagram matches the repository: controller pods run at HQ and send
Tuya commands over the LAN. The LED follows solar watts; the fan remains on in
sun/cloud and scales to zero in blackout. It demonstrates renewable availability,
not a measured reduction in grid carbon.

Slide 5 links the demo configuration to
[our feel-the-breeze project](https://github.com/depeche-io/kcd-2026/tree/main/feel-the-breeze),
specifically its `pi/` and `hq/` directories.

Slide numbers live in `slide-bottom.vue` (the per-slide layer), so PDF export
uses each slide’s own number rather than the global navigation page.
