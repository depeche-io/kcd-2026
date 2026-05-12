<script setup lang="ts">
defineProps<{
  rows: Array<{
    icon: string
    label: string
    distance: string
    kg: number
    display: string
  }>
}>()
</script>

<template>
  <div class="co2-bar">
    <div v-for="row in rows" :key="row.label" class="row">
      <div class="meta">
        <span class="icon">{{ row.icon }}</span>
        <span class="label">{{ row.label }}</span>
        <span class="dist">{{ row.distance }}</span>
      </div>
      <div class="track">
        <div
          class="fill"
          :style="{ width: Math.min(100, (row.kg / 47) * 100) + '%' }"
        />
        <span class="value">{{ row.display }} kg CO₂e</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.co2-bar {
  display: flex;
  flex-direction: column;
  gap: 0.7rem;
  width: 100%;
}
.row {
  display: grid;
  grid-template-columns: 1fr 2fr;
  gap: 1rem;
  align-items: center;
}
.meta {
  display: flex;
  gap: 0.5rem;
  align-items: baseline;
  font-size: 0.95rem;
}
.icon {
  font-size: 1.4rem;
}
.label {
  font-weight: 600;
}
.dist {
  color: #6b7280;
  font-size: 0.8rem;
}
.track {
  position: relative;
  height: 1.8rem;
  background: #e2e8f0;
  border: 1px solid #cbd5e1;
  border-radius: 4px;
  overflow: hidden;
}
.fill {
  height: 100%;
  background: linear-gradient(90deg, #0086FF, #ff5e3a);
  transition: width 0.6s ease;
}
.value {
  position: absolute;
  right: 0.5rem;
  top: 50%;
  transform: translateY(-50%);
  font-size: 0.85rem;
  font-weight: 600;
  color: #0a0a0a;
}
</style>
