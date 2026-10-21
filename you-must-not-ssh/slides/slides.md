---
theme: default
colorSchema: 'dark'
title: '"YOU MUST NOT ssh!"'
info: |
  "YOU MUST NOT ssh!" and Other Stories from Building Our SRE Agent
  Cloud Native Days Poland 2026 — David Pech
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
vite:
  server:
    hmr:
      overlay: false
    fs:
      allow:
        - '.'
        - '/'

---

# "YOU MUST NOT ssh!" 🚨🤖

## and Other Stories from Building Our SRE Agent

<div class="mt-10 text-lg opacity-90">
  <strong>David Pech</strong> — Wrike
</div>

<div class="abs-bl m-6 text-sm opacity-75">
  Cloud Native Days Poland 2026 · Warsaw
</div>

<div class="abs-br m-6 text-sm opacity-75">
  #CNDPoland2026 #CloudNativeDays #CloudNative #CNCF #Kubernetes
</div>

---

# Who

<div class="flex flex-col items-center justify-center h-[80%] gap-6">

<img src="/david-pech.jpg" class="rounded-full w-44 h-44 object-cover ring-4 ring-blue-400 shadow-2xl" />

<div class="text-4xl font-bold tracking-tight">David Pech</div>

<div class="flex items-center gap-12 mt-2">
  <img src="/wrike-logo.svg" class="h-16" style="filter: brightness(0) invert(1);" />
  <img src="/kubestronaut.png" class="h-24" />
</div>

</div>

---

# The Golden Grail of SRE Agents

<div class="grid grid-cols-[1fr_1fr] gap-12 mt-8">

<div>

## What KubeCon EU was about

- **Every other booth** had an "AI SRE"
- Same demo, same Slack screenshot
- Same promise: **no more on-call pages**

## Reality Check

- 🏷️ Seeing 80% of booths for the last time
- 🧪 Just a few vendors with real production "read-write" experience
- 🔌 **MCP-everywhere** - just wrapping original API servers oftentimes

</div>

<div>

## The pitch in one line

<div class="kcd-card mt-4 text-lg">
  Alert fires → agent investigates → agent fixes your precious production
</div>

<img src="/trollface.png" class="mx-auto mt-8 h-44" />

</div>

</div>

---

# Booth promise: the "$$$ profit" demo 💰

<div class="grid grid-cols-2 gap-6 mt-4">

<div>

```
┌────────────────────────────────────────────┐
│ 🚨 Slack #alerts                           │
│ ──────────────────────────────────────────│
│ PrometheusAlert: payments-api OOMKilled    │
│ namespace=prod, container=app, restarts=7  │
└────────────────────────────────────────────┘
                    ▼
   you: @agent increase mem for the app
                    ▼
   🤖 agent: opened PR #4172 in gitops/prod
            +  memory: 768Mi → 1Gi
            +  -Xmx768m → -Xmx896m
                    ▼
              🟢 PR auto-merged
              🟢 ArgoCD synced
                    ▼
                💰 $$$ profit
```

</div>

<div>

### What this demo silently assumes

<div class="grid gap-2">
  <div class="kcd-card">🧭 The agent already knows <strong>which</strong> GitOps repo, <strong>which</strong> overlay, <strong>which</strong> file</div>
  <div class="kcd-card">🪪 The agent has <strong>write</strong> credentials to a prod repo</div>
  <div class="kcd-card">🤝 The on-call person <strong>trusts</strong> a one-line Slack request</div>
  <div class="kcd-card">🧠 +25% memory is actually the right fix (not a leak, not a noisy neighbor)</div>
  <div class="kcd-card">🔁 No one cycles the agent into a feedback loop with itself</div>
</div>

</div>

</div>

---

# POC: Proof of Concept 🛠️

<img src="/logo.png" alt="logo.png" class="abs-tr m-6 max-h-24 rounded shadow" />

<div class="inline-block text-xl mt-2 px-4 py-2 rounded-lg" style="background:linear-gradient(135deg,#7c3aed 0%,#0086FF 100%); color:#fff;">
  internal "Product" <span class="opacity-80">←</span> <strong>the most important part</strong>
</div>

<div class="text-6xl text-center my-1">🤷</div>

<div class="grid grid-cols-2 gap-4 mt-2">

<div class="kcd-card">
  <strong>Who is it for?</strong>
  <ul class="mt-1">
    <li>We are not sure</li>
    <li>Ops + maybe: DevOps, Developers, Managers…</li>
  </ul>
</div>

<div class="kcd-card kcd-card-warn">
  <strong>What should it do?</strong>
  <ul class="mt-1">
    <li>We don't know</li>
    <li>Investigate, research, maybe: fix things? Do we really want that?</li>
  </ul>
</div>

</div>

<div class="kcd-card kcd-card-ok mt-4 text-sm">
  <strong>Covered use-cases:</strong>
  <ul class="mt-1">
    <li>what is our setup of app Kafka cluster in QA</li>
    <li>do we serve domain X via Cloudflare?</li>
    <li>translate IP 10.1.2.3 to hostname</li>
  </ul>
  <div class="mt-2">+ Slack <code>@integration</code> <span class="opacity-70">(now Claude Tag)</span></div>
</div>

---

# POC: Results ~January-March

<div class="text-lg leading-relaxed mt-4">

- Python vibe-coded app on top of <code>Claude Agent SDK</code>
  - With MCPs to PagerDuty, VictoriaMetrics, Netbox, ...
- Tapped into Slack channels (both human and alerting)
- Bundled a lot of our repos
  - Wikis
  - Docs
  - GitOps repos
  - Terraform repos
  - ...
- Workflow: what to do (context)

</div>

<div class="abs-b mx-14 mb-8 text-sm">
<table>
  <thead><tr><th>Runtime</th><th>Credentials</th><th>Users</th><th>Tokens spent</th></tr></thead>
  <tbody><tr><td>locally + skills</td><td><code>$HOME</code></td><td>? SysOps Juniors (but we don't have those)</td><td>~$2k</td></tr></tbody>
</table>
</div>

---

# POC: Mistakes

<div class="mt-3 mb-3 text-center text-3xl py-6 rounded-lg" style="background:linear-gradient(135deg,#7c3aed 0%,#0086FF 100%); color:#fff; font-weight:700; letter-spacing:0.02em;">
  ✨ &nbsp; AI &nbsp; magic &nbsp; will &nbsp; happen<sup class="text-base align-super">™</sup> &nbsp; ✨
</div>

**Main problem**: too generic, not much added value.

Intended direction:

- ❌ Understand larger picture from multiple alerts at the same time
- ❌ Fix the issue in QA <span class="opacity-70">(note: PROD was never target)</span>
- ❌ Keep session open
- ❌ Don't pollute with thinking
- ❌ Do not allow any tools except for `Read`, `Glob`...
- ❌ Semi-legacy Wiki exported into context

---

# What Can You Get Without Context: Guess Work

<div class="grid grid-cols-[3fr_2fr] gap-6 mt-2 items-center">

<div class="grid grid-cols-2 gap-3 items-center">
  <img src="/pagerduty-event.png" alt="pagerduty-event.png" class="rounded shadow block max-w-full object-contain max-h-96" />
  <img src="/pagerduty-sre-agent.png" alt="pagerduty-sre-agent.png" class="rounded shadow block max-w-full object-contain max-h-96" />
</div>

<div>

Resume: Not bad given how little context it has.

Useful: absolutely not.

> @PagerDuty booth discussion on KubeCon NA 2025: "Can we add more context?" "No."
> (but it might have changed since...)

</div>

</div>

---

# You Need to Provide More Context

<span style="color:var(--kcd-blue)">**Our approach**</span>:
- mimic the local Claude Code setup
- mono-repo style

Problem:
- CLAUDE.md (AGENTS.md) in each repo
- You should not provide out-of-date, legacy information <span class="px-2 py-1 rounded font-bold" style="background:var(--kcd-danger); color:#fff;">THIS IS BIG</span>

<div class="kcd-card kcd-card-danger mt-3 text-base">
  🔥 <strong>Stale context = confident wrong answers.</strong>
  Pruning beats hoarding.
</div>

---

# MCP vs. tool use for Wiki

For some reason - MCP significantly less effective.

Medium sized wiki (1000 pages):
- grep and other basic agent tools are very effective

GitOps repos

<span style="color:var(--kcd-blue)">**Our approach**</span>:
- move from some proprietary wiki to Markdown
- we needed to recreate wiki from scratch

Typically 30 - 110 tool uses (Grep|Read|Glob) for a single prompt

~80MB of context, 8MB .tf, 3MB .md

---

# Session vs. Separate each run

<div class="grid grid-cols-2 gap-6 mt-4 items-center">

<div>

Note: Token caching: 5 mins

<span style="color:var(--kcd-blue)">**Our approach**</span>:
- each @mention is a new session

Trade-off:
- fewer tokens
- more time taken each run
- some details are lost

Surprisingly - not a problem

</div>

<div>

Example:

```
- Alert A.
- You: @ops-responder-agent - find the definition of the alert
- Agent: Definition is ...
- You: @ops-responder-agent - based on the alert definition do X
- Agent: (start from scratch)
```

</div>

</div>

---

# Slack Context

Our original idea:
- we absolutely must share the context of all Slack alerting channels, so the agent is aware of the general situation and can leverage it

<div class="grid grid-cols-2 gap-6 mt-2 items-center">

<div>
  <img src="/slack-input.png" alt="slack-input.png" class="rounded shadow mx-auto block max-w-full object-contain max-h-44" />
</div>

<div>
  <img src="/slack-orientation.png" alt="slack-orientation.png" class="rounded shadow mx-auto block max-w-full object-contain max-h-44" />
</div>

</div>

<div class="mt-4 text-sm">
<table>
  <thead><tr><th>POC</th><th>V1</th></tr></thead>
  <tbody><tr><td>Generate up-to-date Slack dump, caching + handling Slack</td><td>Replace with MCP called on-demand, saving 20s on each prompt (copying of the context each prompt)</td></tr></tbody>
</table>
</div>

---

# Problem: Slack Context

- it uses tools like Grep|Sed - skips the context on purpose

<img src="/slack-error.png" alt="slack-error.png" class="rounded shadow my-2 mx-auto block max-w-full object-contain max-h-32" />
<img src="/slack-error-2.png" alt="slack-error-2.png" class="rounded shadow my-2 mx-auto block max-w-full object-contain max-h-32" />

<div class="mt-4 text-sm">
<table>
  <thead><tr><th>POC</th><th>V1</th></tr></thead>
  <tbody><tr><td>No further support</td><td>CLAUDE.md's almost everywhere, guidance in the context</td></tr></tbody>
</table>
</div>

---

# Problem: Context Or Code?

Slack Output, Slack Fetching

Hard to decide, even having both and experimenting between them.

---

# Slack Output

<div class="grid grid-cols-2 gap-6 mt-4 items-center">

<div>

- no formatting
- have a script replace .md / something to `Block Kit`
- explain that in a context

</div>

<div>
  <img src="/slack-output.png" alt="slack-output.png" class="rounded shadow mx-auto block max-w-full object-contain max-h-96" />
</div>

</div>

---

# Problem: Output Gets Polluted

Thinking: off

"Extended thinking"

<div class="grid grid-cols-2 gap-6 mt-3 items-center">

<div class="flex flex-col gap-2">
  <img src="/slack-broken.png" alt="slack-broken.png" class="rounded shadow mx-auto block max-w-full object-contain max-h-32" />
  <img src="/slack-broken2.png" alt="slack-broken2.png" class="rounded shadow mx-auto block max-w-full object-contain max-h-48" />
</div>

<div>
  <img src="/force-output.png" alt="force-output.png" class="rounded shadow mx-auto block max-w-full object-contain max-h-72" />
</div>

</div>

---

# Problem: How to Get Result in a Reasonable Time

<img src="/timeout.png" alt="timeout.png" class="rounded shadow my-2 mx-auto block w-full object-contain max-h-32" />

<div class="grid grid-cols-2 gap-6 mt-3 items-center">

<div>

Highly model + thinking budget dependent.

It doesn't work well. Number of steps was even worse.

Also - we can't easily switch fast. vs in-depth answers.

</div>

<div>
  <img src="/timeout-definition.png" alt="timeout-definition.png" class="rounded shadow mx-auto block max-w-full object-contain max-h-56" />
</div>

</div>

<div class="mt-3 text-sm">
<table>
  <thead><tr><th>POC</th><th>V1</th></tr></thead>
  <tbody><tr><td>Opus</td><td>Sonnet</td></tr></tbody>
</table>
</div>

---

# Problem: MCP on top of API

<div class="grid grid-cols-2 gap-6 mt-4 items-center">

<div>

- MCP tools are not aligned to human prompting
- IDs vs. human-readable

<span style="color:var(--kcd-blue)">**Our approach**</span>:
- `/init`-like instruction for such MCPs

</div>

<div>
  <img src="/mcp-netbox.png" alt="mcp-netbox.png" class="rounded shadow mx-auto block max-w-full object-contain max-h-96" />
</div>

</div>

---

# Problem: MCPs Expose Too Much Data

- Superadmin token will give you all the teams in your company
- You need only those that have category 'ops'

Either you spend tokens on each usage + time or it doesn't work well.

<img src="/pd-instructions.png" alt="pd-instructions.png" class="rounded shadow mt-4 mx-auto block w-full object-contain max-h-40" />

---

# Claude Code vs. Claude Agent SDK

Same thing, so they say...

Problem: 60s for MCP startup - fails 10% of the time

<span style="color:var(--kcd-blue)">**Our approach**</span> — retry the evaluation 3 times on this failure.

Problem: either use allowList for permission or callback function for "Bash" tool

<span style="color:var(--kcd-blue)">**Our approach**</span>: yes, we parse shell ourselves...

<span class="opacity-70 italic">HolmesGPT (at the time): BB-gun</span>

---

# Problem: Is this Bash safe?

The agent wants to run tool Bash: `...`

(New feature - auto-mode classifier)

`python vibe-coded-script-previously-written.py`

<span class="opacity-70 italic">...and try to get a security approval over here...</span>

<span style="color:var(--kcd-blue)">**Our approach**</span>:
- Writing into the context folder is not allowed
- Only a very limited allowlist of commands, no piping `|`

Not great...

---

# V1: What Actually Works ~April-August

<div class="grid grid-cols-2 gap-4 mt-4">

<div class="kcd-card">
  <strong>Who is it for?</strong>
  <ul class="mt-1">
    <li>SysOps</li>
    <li>some Engineering Managers</li>
  </ul>
</div>

<div class="kcd-card kcd-card-warn">
  <strong>What should it do?</strong>
  <ul class="mt-1">
    <li>automatically suggest actions</li>
    <li>react on user prompts</li>
  </ul>
</div>

</div>

<div class="kcd-card kcd-card-ok mt-4 text-sm">
  <strong>Covered use-cases:</strong>
  <ul class="mt-1">
    <li>explain the request path for wrike.com/ <span class="opacity-70">(80% correct)</span></li>
    <li>is this alert recurring?</li>
    <li>are we vulnerable?</li>
    <li>...</li>
  </ul>
</div>

<div class="abs-b mx-14 mb-8 text-sm">
<table>
  <thead><tr><th>Runtime</th><th>Credentials</th><th>Users</th><th>Tokens spent</th></tr></thead>
  <tbody><tr><td>remote</td><td>shared read-only tokens</td><td>SysOps</td><td>~$5k</td></tr></tbody>
</table>
</div>

---

# How People Interact With SRE Agent

<img src="/example-cant-do.png" alt="example-cant-do.png" class="rounded shadow my-2 mx-auto block max-w-full object-contain max-h-72" />

---

# Examples

<div class="grid grid-cols-2 gap-6 mt-4 items-center">

<div>
  <img src="/examples-1.png" alt="examples-1.png" class="rounded shadow mx-auto block max-w-full object-contain max-h-96" />
</div>

<div>
  <img src="/examples-2.png" alt="examples-2.png" class="rounded shadow mx-auto block max-w-full object-contain max-h-96" />
</div>

</div>

---

# General recon vs. research 🔍

<div class="grid grid-cols-3 gap-4 mt-4 items-center">

<div>
  <img src="/kafka-1.png" alt="kafka-1.png" class="rounded shadow mx-auto block max-w-full object-contain max-h-96" />
</div>

<div>
  <img src="/kafka-2.png" alt="kafka-2.png" class="rounded shadow mx-auto block max-w-full object-contain max-h-96" />
</div>

<div>
  <img src="/db.png" alt="db.png" class="rounded shadow mx-auto block max-w-full object-contain max-h-96" />
</div>

</div>

---

# Research: "are we vulnerable?" 🛡️

<img src="/vulnerable.png" alt="vulnerable.png" class="rounded shadow my-2 mx-auto block w-full object-contain max-h-[28rem]" />

---

# Recurring & historical fixes 🔁

<div class="grid grid-cols-2 gap-6 mt-4 items-center">

<div>
  <img src="/recurring.png" alt="recurring.png" class="rounded shadow mx-auto block max-w-full object-contain max-h-96" />
</div>

<div>
  <img src="/recurring-2.png" alt="recurring-2.png" class="rounded shadow mx-auto block max-w-full object-contain max-h-96" />
</div>

</div>

---

# Provide links 🔗

<img src="/links.png" alt="links.png" class="rounded shadow my-2 mx-auto block w-full object-contain max-h-[28rem]" />

---

# Big Win: Metrics MCP

<div class="grid grid-cols-2 gap-6 mt-4 items-center">

<div>

<div class="kcd-card kcd-card-ok mb-4">Very surprising for us that Claude can really understand the time series.</div>

Not there yet:
Predict `when disk will be full`

(Logs and Traces coming...)

</div>

<div>
  <img src="/metrics.png" alt="metrics.png" class="rounded shadow mx-auto block max-w-full object-contain max-h-96" />
</div>

</div>

---
class: text-center
---

<div class="flex flex-col items-center justify-center h-full gap-4" style="background:linear-gradient(135deg,#0a1628 0%,#0d2a4a 100%);">
  <div class="text-blue-400 text-lg font-mono tracking-widest uppercase opacity-70">Part III</div>
  <div class="text-5xl font-bold text-white">Trust &amp;</div>
  <div class="text-5xl font-bold text-white">Security</div>
</div>

---

# Security Layers

<img src="/security-layers.png" alt="security-layers.png" class="rounded shadow my-2 mx-auto block w-full object-contain max-h-[28rem]" />

---

# Security: secrets & context 🔒

<img src="/secrets.png" alt="secrets.png" class="rounded shadow my-2 mx-auto block max-w-full object-contain max-h-60" />

---

# Do we trust it?

<div class="my-8 text-center text-6xl py-10 rounded-lg" style="background:linear-gradient(135deg,var(--kcd-danger) 0%,#7c2d12 100%); color:#fff; font-weight:800; letter-spacing:-0.01em; text-shadow:0 2px 8px rgba(0,0,0,0.3);">
  Absolutely no. <span class="opacity-80 text-3xl align-middle">(period)</span>
</div>

You must have separate tokens as limited as you can have.

---

# Prepare a Patch

<span style="color:var(--kcd-blue)">**Our approach**</span> — too scared so far to give a GitLab token

<img src="/patch.png" alt="patch.png" class="rounded shadow my-2 mx-auto block w-full object-contain max-h-[28rem]" />

---

# Problem: User Trust Lost

<img src="/trust-1.png" alt="trust-1.png" class="rounded shadow my-2 mx-auto block max-w-full object-contain max-h-32" />
<img src="/trust-2.png" alt="trust-2.png" class="rounded shadow my-2 mx-auto block max-w-full object-contain max-h-32" />

---

# Getting Feedback - Slack Reactions

<img src="/reaction-1.png" alt="reaction-1.png" class="rounded shadow my-2 mx-auto block max-w-full object-contain max-h-24" />
<img src="/reaction-2.png" alt="reaction-2.png" class="rounded shadow my-2 mx-auto block max-w-full object-contain max-h-32" />
<img src="/reaction-3.png" alt="reaction-3.png" class="rounded shadow my-2 mx-auto block max-w-full object-contain max-h-24" />

---

# Real Adoption?

<img src="/harold-meme.jpg" alt="harold-meme.jpg" class="rounded shadow my-2 mx-auto block max-w-full object-contain max-h-60" />

---

# Key takeaways

<div class="grid grid-cols-1 gap-5 mt-10">

<div class="kcd-card text-xl py-4 px-6">
  <span class="text-3xl mr-3">1️⃣</span> Kick-off with what you have locally.
</div>

<div class="kcd-card text-xl py-4 px-6">
  <span class="text-3xl mr-3">2️⃣</span> Start small and build iteratively.
</div>

<div class="kcd-card text-xl py-4 px-6">
  <span class="text-3xl mr-3">3️⃣</span> It's Product - focus on value it brings and user feedback.
</div>

</div>

---

# Real takeaways

<div class="grid grid-cols-1 gap-5 mt-10">

<div class="kcd-card text-xl py-4 px-6">
  <span class="text-3xl mr-3">1️⃣</span> Build your SRE Agent.
</div>

<div class="kcd-card text-xl py-4 px-6">
  <span class="text-3xl mr-3">2️⃣</span> Become an AI Engineer.
</div>

<div class="kcd-card kcd-card-danger text-2xl py-5 px-6" style="box-shadow:0 0 24px rgba(239,68,68,0.5); transform:scale(1.03);">
  <span class="text-4xl mr-3">3️⃣</span> <strong>Secure your job.</strong> 🔒
</div>

</div>

---
class: text-center
---

# Thank you 🤖

<div class="mt-4 text-xl">
  Questions? Stories from your own SRE-agent build? Find me in the hallway.
</div>

<div class="grid grid-cols-2 gap-8 items-start mt-8">

<div class="flex flex-col items-center">
  <img src="/feedback-qr.png" class="rounded" style="height:240px;" />
  <div class="mt-3 text-lg font-bold">Rate this talk ⭐</div>
</div>

<div class="flex flex-col items-center">
  <QRCode
    :width="220"
    :height="220"
    type="svg"
    data="https://github.com/depeche-io/kcd-2026/tree/main/you-must-not-ssh"
    :margin="4"
    :dotsOptions="{ color: '#ffffff' }"
    :backgroundOptions="{ color: '#003a99' }"
  />
  <div class="mt-3 text-lg font-bold">Slides + notes</div>
</div>

</div>

<div class="abs-bl m-6 text-sm opacity-75">
  Cloud Native Days Poland 2026 · #CNDPoland2026 #CloudNativeDays #CloudNative #CNCF #Kubernetes
</div>
