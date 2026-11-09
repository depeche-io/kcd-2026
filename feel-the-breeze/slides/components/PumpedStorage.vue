<script setup lang="ts">
// Schematic, not to scale: pumped-storage hydro shifts energy from cheap/clean hours to peaks.
</script>

<template>
  <svg viewBox="0 0 300 210" class="pumped" role="img" aria-label="Pumped-storage hydro: pump water uphill when the grid is clean, release it through turbines at peak demand">
    <!-- hill -->
    <path d="M0,200 L0,70 L95,52 L150,110 L210,175 L300,185 L300,200 Z" class="hill" />
    <!-- upper reservoir -->
    <path d="M18,66 Q55,92 92,58 Z" class="water" />
    <text x="52" y="44" class="label" text-anchor="middle">Upper reservoir</text>
    <!-- penstock -->
    <path d="M88,62 L200,172" class="pipe" />
    <!-- powerhouse -->
    <rect x="192" y="160" width="26" height="20" rx="3" class="house" />
    <text x="205" y="174" class="icon" text-anchor="middle">⚡</text>
    <!-- lower reservoir -->
    <path d="M222,180 Q258,200 296,184 Z" class="water" />
    <text x="258" y="206" class="label" text-anchor="middle">Lower reservoir</text>
    <!-- flows -->
    <path d="M160,100 L118,58" class="arrow up" marker-end="url(#ah-up)" />
    <text x="150" y="54" class="tag up">🌙 clean / cheap: pump up</text>
    <path d="M128,128 L170,170" class="arrow down" marker-end="url(#ah-down)" />
    <text x="6" y="120" class="tag down">🔥 peak: flow down,</text><text x="6" y="134" class="tag down">generate power</text>
    <defs>
      <marker id="ah-up" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path d="M0,0 L10,5 L0,10 Z" class="head up" /></marker>
      <marker id="ah-down" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path d="M0,0 L10,5 L0,10 Z" class="head down" /></marker>
    </defs>
  </svg>
</template>

<style scoped>
.pumped { width: 100%; height: auto; }
.hill { fill: var(--kc-purple); fill-opacity: 0.55; }
.water { fill: var(--kc-blue); fill-opacity: 0.8; }
.pipe { stroke: var(--kc-lavender); stroke-width: 4; stroke-linecap: round; }
.house { fill: var(--kc-navy-dark); stroke: var(--kc-lavender); stroke-width: 1.5; }
.icon { font-size: 12px; }
.label { fill: var(--kc-lavender); font-size: 10px; }
.arrow { stroke-width: 2.5; fill: none; }
.arrow.up, .head.up { stroke: var(--kc-ok); fill: var(--kc-ok); }
.arrow.down, .head.down { stroke: var(--kc-bee); fill: var(--kc-bee); }
.arrow.up, .arrow.down { fill: none; }
.tag { font-size: 10.5px; font-weight: 700; }
.tag.up { fill: var(--kc-ok); }
.tag.down { fill: var(--kc-bee); }
</style>
