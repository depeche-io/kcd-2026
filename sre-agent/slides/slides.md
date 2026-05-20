---
theme: default
title: 'We Built an AI Incident Responder'
info: |
  We Built an AI Incident Responder. Here's What We Got Wrong.
  KCD Czech-Slovak 2026 — David Pech
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

# We Built an AI Incident Responder 🚨🤖

## Here's What We Got Wrong.

<div class="mt-10 text-lg opacity-90">
  <strong>David Pech</strong> — Wrike
</div>

<div class="abs-bl m-6 text-sm opacity-75">
  KCD Czech-Slovak 2026 · Prague
</div>

<div class="abs-br m-6 text-sm opacity-75">
  #SREAgent · #KCDCzechSlovak2026
</div>


---

# Intro: who, what, why

<div class="grid grid-cols-[1fr_2fr] gap-10 mt-4">

<div>

### Who am I

<div class="kcd-card mt-2">
  <strong>David Pech</strong><br/>
  Platform / SRE @ <strong>Wrike</strong><br/>
  <span class="opacity-80 text-sm">Kubernetes · AWS · Postgres · Argo · Puppet legacy</span>
</div>

<div class="mt-4 text-sm opacity-80">
  Previously: KCD '24 / '25 speaker (sustainability, GitOps).<br/>
  This year: <em>SRE agents — the honest version.</em>
</div>

</div>

<div>

### Why this talk

- We — like seemingly everyone in this room — spent the last year building an "SRE agent"
- Most vendor demos are <strong>a junior sysadmin in a trench coat</strong>
- I want to share what <strong>actually worked</strong>, what didn't, and what surprised us

### The honest split

- 1/3 vibe-coding Python &nbsp;<span class="kcd-pill">easy</span>
- 1/3 prompt + context engineering &nbsp;<span class="kcd-pill">80→95%</span>
- 1/3 **security** &nbsp;<span class="kcd-pill" style="background:var(--kcd-danger)">hard</span>

</div>

</div>


---

# The Golden Grail of SRE Agents

<div class="grid grid-cols-[1fr_1fr] gap-12 mt-8">

<div>

## What KubeCon was about

- **Every other booth** had an "AI SRE"
- Same demo, same Slack screenshot
- Same promise: **no more on-call pages**

</div>

<div>

## The pitch in one line

<div class="kcd-card mt-4 text-lg">
  Alert fires → agent investigates → agent fixes your precious production
</div>

<div class="mt-6 text-base opacity-85">
  Sounds great. Reality is messier.
</div>

</div>

</div>


---

# The Golden Grail of SRE Agents

<div class="grid grid-cols-[1fr_1fr] gap-12 mt-8">

<div>

## Reality Check

- 🏷️ Seeing 80% of booths for the last time
- 🧪 Just a few vendor with real production "read-write" experience
- 🔌 **MCP-everywhere** - just wrapping original API servers oftentimes

</div>

<div>

## Realistic Pitch

<div class="mt-3 grid gap-2 text-sm">
  <div class="kcd-card kcd-card-warn">⚠️ <strong>Investigates</strong> = reads dashboards it was told about. New service? It doesn't know.</div>
  <div class="kcd-card kcd-card-warn">⚠️ <strong>Fixes</strong> = opens a PR. Someone still merges. Often that's *you*, at 3 AM.</div>
  <div class="kcd-card kcd-card-danger">⛔ <strong>Stay asleep</strong> = until the agent confidently does the wrong thing, twice, in prod.</div>
  <div class="kcd-card kcd-card-ok">✅ <strong>Realistic win</strong>: cut the "context-gathering" minutes of an incident from 20 → 2.</div>
</div>

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
   you: @agent increase mem for the agent
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

# What we actually shipped 🛠️

<img src="/logo.png" alt="logo.png" class="abs-tr m-6 max-h-24 rounded shadow" />

<div class="text-lg opacity-95 mt-2">
  internal "Product" <span class="opacity-70">←</span> <strong>the most important part</strong>
</div>

<div class="text-7xl text-center my-4">🤷</div>

<div class="grid grid-cols-2 gap-4 mt-2">

<div class="kcd-card">
  <strong>Who is it for?</strong>
  <ul class="mt-1">
    <li>We are not sure</li>
    <li>Ops + maybe: DevOps, Developer, Managers…</li>
  </ul>
</div>

<div class="kcd-card kcd-card-warn">
  <strong>What it should do?</strong>
  <ul class="mt-1">
    <li>We don't know</li>
    <li>Investigate, research, maybe: fix things? Do we really want that?</li>
  </ul>
</div>

</div>


---

# Technicals

<div class="text-lg leading-relaxed mt-4">

- Python vibe-coded app on top of <code>Claude Agent SDK</code>
  - With MCPs to PagerDuty, VictoriaMetrics, Netbox, ...
- Tapped to Slack channels (both human and alerting)
- Bundled a lot of our repos
  - Wikis
  - Docs
  - GitOps repos
  - Terraform repos
  - ...
- Workflow what to do (context)

</div>


---

# Wrong Approach

Vendor are selling the tool: `run agent on your alerts,`

<div class="mt-3 mb-3 text-center text-3xl py-6 rounded-lg" style="background:linear-gradient(135deg,#7c3aed 0%,#0086FF 100%); color:#fff; font-weight:700; letter-spacing:0.02em;">
  ✨ &nbsp; AI &nbsp; magic &nbsp; will &nbsp; happen<sup class="text-base align-super">™</sup> &nbsp; ✨
</div>

Our `ops-responder-agent`:
- could sell you fresh bread over Slack with a different context...
- can be replaced with Gemini Enterprise or any other in a month

Your wrapper around real agent is not much important and likely will change.

Context and the workflow are.



---

# What Can You get Without Context


<img src="/pagerduty-event.png" alt="pagerduty-event.png" class="rounded shadow my-2 mx-auto block max-w-full object-contain max-h-72" />

---

# Guess Work

<div class="grid grid-cols-2 gap-6 mt-4 items-center">

<div>
  <img src="/pagerduty-sre-agent.png" alt="pagerduty-sre-agent.png" class="rounded shadow mx-auto block max-w-full object-contain max-h-96" />
</div>

<div>

Resume: Not bad given how few context it has.

Useful: absolutely not.

> @PagerDuty booth discussion on KubeCon NA 2025: "Can we add more context?" "No."
> (but it might have changed since...)

</div>

</div>


---

# You Need to Provide More Context

Our approach:
- mimic the local Claude Code setup
- mono-repo style

Problem:
- CLAUDE.md (AGENTS.md) in each repo
- You should not provide out-of-date, legacy information (**THIS IS BIG**)

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

Our approach:
- move from some proprietary wiki to Markdown
- we needed to recreate wiki from scratch

Typically 30 - 110 tool uses (Grep|Read|Glob) for single prompt

~80MB of context, 8MB .tf, 3MB .md


---

# Session vs. Separate each run

<div class="grid grid-cols-2 gap-6 mt-4 items-center">

<div>

Note: Token caching: 5 mins

Our Approach:
- each @mention is a new session

Trade-off:
- less tokens
- more time taken each run
- some details are lost

Suprisingly - not a problem

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

# Problem: How to Get Result in Reasonable time

<img src="/timeout.png" alt="timeout.png" class="rounded shadow my-2 mx-auto block w-full object-contain max-h-32" />

<div class="grid grid-cols-2 gap-6 mt-3 items-center">

<div>

Highly model + thiking budget dependant.

It doesn't work well. Number of steps was even worse.

Also - we can't easily switch fast. vs in-depth answers.

</div>

<div>
  <img src="/timeout-definition.png" alt="timeout-definition.png" class="rounded shadow mx-auto block max-w-full object-contain max-h-72" />
</div>

</div>


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

# Problem: MCP on top of API

<div class="grid grid-cols-2 gap-6 mt-4 items-center">

<div>

- MCP tools are not aligned to human promptingo
- IDs vs. human-readable

Our Approach:
- `/init`-like instruction for such MCPs

</div>

<div>
  <img src="/mcp-netbox.png" alt="mcp-netbox.png" class="rounded shadow mx-auto block max-w-full object-contain max-h-96" />
</div>

</div>

---

# Problem: MCP Offer Too Wide Data

- Superadmin token will give you all the teams in your company
- You need only those that have category 'ops'

Either you spend tokens on each usage + time or doesn't work well.

<img src="/pd-instructions.png" alt="pd-instructions.png" class="rounded shadow mt-4 mx-auto block w-full object-contain max-h-40" />


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

# Claude Code vs. Claude Agent SDK

Same thing, so they say...

Problem: 60s for MCP startup - fails 10% times

Our approach - retry 3 times the evalution on this failure.

Problem: either use allowList for permission or callback function for "Bash" tool

Our approach: yes, we parse shell ourselves...


---

# Problem: Is this Bash safe?

Agents wants to run tool Bash: `...`

(New feature - auto-mode classifier)

`python vibe-coded-script-previously-written.py`

Our Approach:
- Write into context folder is not allowed
- Only very limited white-list of command, no piping `|`

Not great...


---

# Problem: Context Or Code?

Slack Output, Slack Fetching

Hard to decide, even having both and experimenting between them.


---

# Slack Context

Our original idea:
- we absolutely must share the context of all slack alerting channels, so the agent is aware of some general situation and can leverage it

<div class="grid grid-cols-2 gap-6 mt-4 items-center">

<div>
  <img src="/slack-input.png" alt="slack-input.png" class="rounded shadow mx-auto block max-w-full object-contain max-h-72" />
</div>

<div>
  <img src="/slack-orientation.png" alt="slack-orientation.png" class="rounded shadow mx-auto block max-w-full object-contain max-h-72" />
</div>

</div>

---

# Problem: Slack Context

- it uses tools like Grep|Sed - skips the context on purpose

<img src="/slack-error.png" alt="slack-error.png" class="rounded shadow my-2 mx-auto block max-w-full object-contain max-h-32" />
<img src="/slack-error-2.png" alt="slack-error-2.png" class="rounded shadow my-2 mx-auto block max-w-full object-contain max-h-32" />

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

Our Approach - too scared so far to give a GitLab token

<img src="/patch.png" alt="patch.png" class="rounded shadow my-2 mx-auto block w-full object-contain max-h-[28rem]" />

---

# Big Win: Metrics MCP

<div class="grid grid-cols-2 gap-6 mt-4 items-center">

<div>

Not there yet:
Predict `when disk will be full`

(Logs and Traces coming...)

</div>

<div>
  <img src="/metrics.png" alt="metrics.png" class="rounded shadow mx-auto block max-w-full object-contain max-h-96" />
</div>

</div>


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

<div class="grid grid-cols-2 gap-8 items-center mt-10">

<div class="text-left text-lg">
  <div class="opacity-90">
    <strong>David Pech</strong><br/>
  </div>
  <div class="mt-6 opacity-90 text-base">
    Slides + notes:<br/>
    <span class="font-mono opacity-80">github.com/depeche-io/kcd-2026</span>
  </div>
</div>

<div class="flex flex-col items-center">
  <QRCode
    :width="220"
    :height="220"
    value="https://github.com/depeche-io/kcd-2026/tree/main/sre-agent"
    render-as="svg"
    type="image/png"
    :margin="1"
    :color="{ dark: '#ffffff', light: '#003a99' }"
  />
  <div class="mt-3 text-sm font-mono opacity-90">
    /sre-agent
  </div>
</div>

</div>

<div class="abs-bl m-6 text-sm opacity-75">
  KCD Czech-Slovak 2026 · #SREAgent · #KCDCzechSlovak2026
</div>

