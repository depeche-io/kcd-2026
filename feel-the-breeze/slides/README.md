# Feel the Breeze — Techmeetup Ostrava 2026

Editable Slidev source: `slides.md`. Deliverable: `feel-the-breeze.pdf`.
The deck has **20 slides: 19 main slides and 1 backup-video slide**.
The presentation is in English for **Techmeetup Ostrava 2026**, November 20, 2026,
at Nová Aula VŠB-TUO in Ostrava-Poruba; see the [official conference page](https://techmeetup.cz/conference/).
This edition changes the visual identity and slide 3 (travel to Ostrava); the
technical content and the worldwide cloud-region comparison retain their current order.

## Speaker scripts

- [English speaker script](speaker-notes.en.md)
- [Česká řeč k prezentaci](speaker-notes.cs.md)

Both scripts follow the current slide titles. Their event introduction and slide 3
have been adapted to Ostrava. The live demo retains its own narration.
They are separate rehearsal documents and do not add slides to the PDF.

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

`style.css` uses the official TechMeetup website's palette: lagoon `#01a182`,
neon `#03ffce`, atlantic `#162635`, and dark `#070D14`. The local
`public/theme/techmeetup-logo.png` is the [official website logo](https://techmeetup.cz/_astro/brand_logo.Cz1bTTO7.png).
Barlow Semi Condensed is bundled locally for headings, alongside Inter and
JetBrains Mono, with font licenses in `public/fonts/`. No web fonts are fetched
when presenting. The previous conference background and Edge Day logo are not used.
The QR code retains the real demo repository URL. Prepare a local backup recording
separately for fully offline playback.

## Data and assumptions

Travel and event identity checked **November 20, 2026**. The technical-source notes below retain their previous verification date of November 4, 2026. Source links also appear on the relevant slides.

### Travel to Ostrava

The slide uses rounded, **illustrative one-way distances**, not live route planning.
For a transparent comparison it applies the CO₂ component of the
[UK DESNZ 2026 conversion factors, full set](https://assets.publishing.service.gov.uk/media/6a29392bade52dc0882218a8/ghg-conversion-factors-2026-full-set.xlsx),
worksheet **Business travel- land**, to these routes. These are **UK reference
factors, not measured Czech Railways, coach-operator or DPO emissions**. They
exclude upstream fuel supply and vehicle manufacture. No claim of a complete
lifecycle footprint is made.

| Example | Assumed distance | CO₂ factor | Modelled kg CO₂/person |
| --- | ---: | ---: | ---: |
| Praha → Ostrava, solo petrol-car driver | 370 vehicle-km | 0.16084 kg/vehicle-km (I53) | 59.5 |
| Praha → Ostrava, train | 350 passenger-km | 0.03056 kg/passenger-km (E87) | 10.7 |
| Brno → Ostrava, coach | 170 passenger-km | 0.03899 kg/passenger-km (E82) | 6.6 |
| Svinov → VŠB-TUO, tram | 6 passenger-km | 0.02093 kg/passenger-km (E89) | 0.13 |
| Poruba → venue, walking | 1 km | zero direct operational emissions | 0 |

The car is allocated to one occupant. Public-transport factors already use a
per-passenger basis; do not divide them by occupancy again.

The hypothetical 5 W workload uses `0.005 kW × 8,760 h = 43.8 kWh/year`.
[MPO's Czech electricity report, 2025 data, Table 1](https://mpo.gov.cz/assets/cz/energetika/statistika/elektrina-a-teplo/2026/4/Metodika-emisni-faktor-CO2_elektrina_2025.pdf)
gives a gross-generation CO₂ factor of `0.33 t/MWh = 0.33 kg/kWh`:
`43.8 × 0.33 = 14.454 kg CO₂/year`, displayed as **~14.5 kg**.
This is a national production proxy, excludes electricity imports/exports, and
is not a measured Ostrava consumption factor. The example covers IT energy only,
with no facility PUE, additional grid losses or embodied hardware emissions.
Five watts remains an assumed workload allocation, not a measured idle-pod baseline.

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
