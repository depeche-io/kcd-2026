<script setup lang="ts">
const props = withDefaults(defineProps<{
  url?: string
  fallback?: string
}>(), {
  url: '',
  fallback: '/kepler-screenshot.png'
})
</script>

<template>
  <div class="kepler-live">
    <iframe
      v-if="props.url"
      :src="props.url"
      frameborder="0"
      allowfullscreen
    />
    <img v-else :src="props.fallback" alt="Kepler dashboard screenshot" />
    <div class="hint">Live: {{ props.url || 'screenshot fallback' }}</div>
  </div>
</template>

<style scoped>
.kepler-live {
  position: relative;
  width: 100%;
  height: 100%;
  min-height: 380px;
  background: #0a0a0a;
  border-radius: 6px;
  overflow: hidden;
}
iframe, img {
  width: 100%;
  height: 100%;
  min-height: 380px;
  display: block;
  object-fit: contain;
}
.hint {
  position: absolute;
  bottom: 0;
  right: 0;
  background: rgba(0, 0, 0, 0.6);
  color: #fff;
  font-size: 0.65rem;
  padding: 0.2rem 0.5rem;
  font-family: monospace;
}
</style>
