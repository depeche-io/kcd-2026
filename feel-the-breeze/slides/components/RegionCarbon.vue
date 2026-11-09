<script setup lang="ts">
// Google Cloud's published 2025 location-based grid intensities (gCO2e/kWh).
// Energy and PUE are explicit teaching assumptions, not N4 telemetry.
const yearlyKwh = 0.080 * 8760 * 1.10
const regions = [
  { location: 'Paris', code: 'europe-west9', intensity: 16, color: '#34d399' },
  { location: 'São Paulo', code: 'southamerica-east1', intensity: 73, color: '#6ee7b7' },
  { location: 'Sydney', code: 'australia-southeast1', intensity: 468, color: '#fef35b' },
  { location: 'Salt Lake City', code: 'us-west3', intensity: 568, color: '#fbbf24' },
  { location: 'Mumbai', code: 'asia-south1', intensity: 598, color: '#fb923c' },
  { location: 'Johannesburg', code: 'africa-south1', intensity: 641, color: '#f87171' },
]
const maximumIntensity = Math.max(...regions.map(region => region.intensity))
</script>

<template>
  <div class="region-chart" role="table" aria-label="Annual operational emissions for identical assumed VM energy use">
    <div class="chart-head" role="row"><span>Region / 2025 grid factor</span><span>kg CO₂e / yr</span></div>
    <div v-for="(region, index) in regions" :key="region.code" class="region-row" role="row">
      <span class="marker" :style="{ background: region.color }">{{ index + 1 }}</span>
      <div class="region-label"><strong>{{ region.location }}</strong><small>{{ region.code }} · {{ region.intensity }} g/kWh</small></div>
      <strong class="amount">~{{ Math.round(yearlyKwh * region.intensity / 1000) }}</strong>
      <div class="bar-track"><div :style="{ width: region.intensity / maximumIntensity * 100 + '%', background: region.color }" /></div>
    </div>
  </div>
</template>

<style scoped>
.chart-head { display:flex; justify-content:space-between; font-size:0.65rem; color:var(--kc-lavender); padding-bottom:0.6rem; }
.region-row { display:grid; grid-template-columns:1.3rem 1fr 3rem; align-items:center; gap:0.1rem 0.5rem; margin-bottom:0.4rem; }
.marker { display:flex; align-items:center; justify-content:center; width:1.2rem; height:1.2rem; border-radius:50%; color:#0b2c60; font-size:0.7rem; font-weight:800; }
.region-label { font-size:0.8rem; line-height:1.1; display:flex; align-items:baseline; gap:0.5rem; }
.region-label small { color:var(--kc-lavender); font-size:0.62rem; white-space:nowrap; }
.amount { text-align:right; font-size:1rem; }
.bar-track { grid-column:2 / 4; height:0.25rem; background:var(--kc-navy-dark); border-radius:3px; margin-top:0.2rem; }
.bar-track div { height:100%; border-radius:3px; }

.region-chart { line-height: 1.2; }
.region-row { line-height: 1.15; margin-bottom: 0.4rem; }
.amount { line-height: 1.1; }
</style>
