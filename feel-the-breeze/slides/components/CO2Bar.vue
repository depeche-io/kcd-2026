<script setup lang="ts">
import { computed } from 'vue'
const props = defineProps<{
  rows: Array<{ icon: string; label: string; distance: string; kg: number; display: string }>
}>()
const maximum = computed(() => Math.max(1, ...props.rows.map(row => row.kg)))
</script>

<template>
  <div class="co2-bar" aria-label="Illustrative travel emissions to Salt Lake City">
    <div v-for="row in rows" :key="row.label" class="row">
      <div class="meta"><span class="icon">{{ row.icon }}</span><span class="label">{{ row.label }}</span><span class="dist">{{ row.distance }}</span></div>
      <div class="track">
        <div class="fill" :style="{ width: Math.min(100, row.kg / maximum * 100) + '%' }" />
        <span class="value">{{ row.display }} kg CO₂</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.co2-bar { display: flex; flex-direction: column; gap: 0.65rem; width: 100%; }
.row { display: grid; grid-template-columns: 1.2fr 1fr; gap: 1rem; align-items: center; }
.meta { display: flex; gap: 0.5rem; align-items: baseline; font-size: 0.9rem; }
.icon { font-size: 1.2rem; }
.label { font-weight: 600; }
.dist { color: var(--kc-lavender); font-size: 0.75rem; margin-left: auto; white-space: nowrap; }
.track { position: relative; height: 1.65rem; background: var(--kc-navy-dark); border: 1px solid #4e73a7; border-radius: 4px; overflow: hidden; }
.fill { height: 100%; background: linear-gradient(90deg, #4e73a7, #8063b6); }
.value { position: absolute; right: 0.5rem; top: 50%; transform: translateY(-50%); font-size: 0.8rem; font-weight: 600; color: white; }
</style>
