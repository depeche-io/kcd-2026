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

<img src="/kcd-logo-white.png" class="abs-tr m-6 h-32 opacity-95" alt="KCD Czech & Slovak" />

<div class="abs-bl m-6 text-sm opacity-75">
  KCD Czech-Slovak 2026 · Prague
</div>

<div class="abs-br m-6 text-sm opacity-75">
  #SREAgent · #KCDCzechSlovak2026
</div>

---
layout: default
---

# Intro: who, what, why

<div class="grid grid-cols-2 gap-8 mt-4">

<div>

### Who
- Platform / SRE team at a mid-sized shop
- Kubernetes, Argo, Prometheus, Puppet legacy
- On-call rotations

### What we built
- A Slack-resident agent: `@ops-responder-agent`
- Answers questions about incidents in **our** stack
- Reads alerts, dashboards, runbooks, git history

</div>

<div>

### Why
- LLM chat is great at *general* — useless at *our* Puppet module at 3 AM
- Most "SRE copilots" are **a junior sysadmin in a trench coat**
- We wanted the agent that knows:
  - which env, which team, which CVE
  - what the last responder said in Slack
  - whether this alert recurs every Tuesday

### The honest split
- 1/3 vibe-coding Python &nbsp;<span class="kcd-pill">easy</span>
- 1/3 prompt engineering &nbsp;<span class="kcd-pill">80→95%</span>
- 1/3 **security** &nbsp;<span class="kcd-pill" style="background:var(--kcd-danger)">hard</span>

</div>

</div>

---
layout: default
---

# The Golden Grail of SRE Agents <span class="kcd-pill">v1 — short</span>

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

<div class="abs-bl m-6 text-sm opacity-70">
  Hold this layout — next slide is the same picture, much more honest.
</div>

---
layout: default
---

# The Golden Grail of SRE Agents <span class="kcd-pill" style="background:var(--kcd-warn)">v2 — broader</span>

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
layout: default
---

# Booth promise: the "$$$ profit" demo 💰

<div class="grid grid-cols-2 gap-6 mt-4">

<div>

### The flow they ship on a 30-second loop

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
              🟢 alert cleared
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
layout: default
---

# What we actually shipped 🛠️


- internal "Product" <- the most important part

TODO: make this slide nice, do NOT ADD more text

TODO: image logo.png

Who is it for?
- We are not sure
- Ops + maybe: DevOps, Developer, Managers...

What it should do?
- We don't know
- Investigate, research, maybe: fix things? Do we really want that?

---
layout: default
---

# Technicals

- Python vibe-coded app on top of `Claude Agent SDK`
  - With MCPs to PagerDuty, VictoriaMetrics, Netbox, ...
- Tapped to Slack channels (both human and alerting)
- Bundled a lot of our repos
  - Wikis
  - Docs
  - GitOps repos
  - Terraform repos
  ...
- Workflow what to do (context)


TODO: make it nicer

---
layout: default
---

# Wrong Approach

Vendor are selling the tool: `run agent on your alerts, magic will happen`

TODO: ai magic will happen

Our `ops-responder-agent`:
- could sell you fresh bread over Slack with a different context...
- can be replaced with Gemini Enterprise or any other in a month

Your wrapper around real agent is not much important and likely will change.

Context and the workflow are.


---
layout: default
---

# What Can You get Without Context


TODO: image pagerduty-event.png


---
layout: default
---

# Guess Work


TODO: image pagerduty-sre-agent.png

Resume: Not bad given how few context it has.

Useful: absolutely not.

@PagerDuty booth discussion on KubeCon NA 2025: "Can we add more context?" "No."
(but it might have changed since...)

---
layout: two-cols
---

# You Need to Provide More Context

Our approach:
- mimic the local Claude Code setup
- mono-repo style

Problem:
- CLAUDE.md (AGENTS.md) in each repo
- You should not provide out-of-date, legacy information (THIS IS BIG)

---
layout: two-cols
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
layout: two-cols
---

# Session vs. Separate each run

Note: Token caching: 5 mins

Our Approach:
- each @mention is a new session

Trade-off:
- less tokens
- more time taken each run
- some details are lost

Suprisingly - not a problem

Example:

```
- Alert A.
- You: @ops-responder-agent - find the definition of the alert
- Agent: Definition is ...
- You: @ops-responder-agent - based on the alert definition do X
- Agent: (start from scratch)
```

---
layout: two-cols
---

# Problem: How to Get Result in Reasonable time

TODO: image timeout.png

Highly model + thiking budget dependant.

TODO: image timeout-definition.png

It doesn't work well. Number of steps was even worse.

---
layout: two-cols
---

# Slack Output

- no formatting
- have a script replace .md / something to `Block Kit`
- explain that in a context

TODO: image slack-output.png

---
layout: two-cols
---

# Problem: Output Gets Polluted

Thinking: off

"Extended thinking"

TODO: image slack-broken.png
TODO: image slack-broken2.png

TODO: image force-output.png

---
layout: two-cols
---

# Problem: MCP on top of API

- MCP tools are not aligned to human promptingo
- IDs vs. human-readable

Our Approach:
- `/init`-like instruction for such MCPs

TODO: image netbox-usage.png


---
layout: two-cols
---

# Problem: MCP Offer Too Wide Data

- Superadmin token will give you all the teams in your company
- You need only those that have category 'ops'

TODO: image pd-instructions.png

Either you spend tokens on each usage + time or doesn't work well.

---
layout: two-cols
---

# How People Interact With SRE Agent

TODO: what can you do


TODO: what you can't do


---
layout: default
---

# Claude Code vs. Claude Agent SDK

Same thing, so they say...

Problem: 60s for MCP startup - fails 10% times

Our approach - retry 3 times the evalution on this failure.

Problem: either use allowList for permission or callback function for "Bash" tool

Our approach: yes, we parse shell ourselves...


---
layout: default
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
layout: default
---

# Problem: Context Or Code?

Slack Output, Slack Fetching

Hard to decide, even having both and experimenting between them.

---
layout: default
---

# Slack Context

Our original idea:
- we absolutely must share the context of all slack alerting channels, so the agent is aware of some general situation and can leverage it

TODO: Screen of MD context

TODO: of benefits

---
layout: default
---

# Problem: Slack Context

- it uses tools like Grep|Sed - skips the context on purpose

TODO: Error - message not found

---
layout: default
---

# Problem: User Trust Lost

TODO: timeout

TODO: face-palm

---
layout: default
---

# Getting Feedback - Slack Reactions

TODO: examples

<div class="opacity-50 text-sm mt-8">[ TODO: fill in — read emoji reactions (facepalm 🤦, 👍, ❌) as signal ]</div>

---
layout: default
---

# General recon vs. research 🔍

TODO: kafka

---
layout: default
---

# Research: "are we vulnerable?" 🛡️

TODO: image

---
layout: default
---

# Recurring & historical fixes 🔁

TODO: image


---
layout: default
---

# Provide links 🔗

TODO: image with links


---
layout: default
---

# Security Layers

TODO: screen from security

---
layout: default
---

# Security: secrets & context 🔒

TODO: screen from protection

---
layout: default
---

# Do we trust it?

Absolutely no. (period)

You must have separate tokens as limited as you can have.

---
layout: default
---

# Prepare a Patch

Our Approach - too scared so far to give a GitLab token

TODO: patch

---
layout: default
---

# Big Win: Metrics MCP

TODO: enumerate use-cases

Not there yet:
Predict `when disk will be full`

---
layout: default
---

# Real Adoption?

TODO: harold smiling

Main Reason: locally you have more powerful setup, accesses etc.

---
layout: default
---

# Key takeaways

Kick-off with what you have locally.

Start small and build iteratively.

It's Product - focus on value it brings and user feedback

---
layout: default
---

# Real takeaways

Build your SRE Agent.

Become an AI Engineer.

Secure your job.

---
layout: cover
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

<img src="/kcd-logo-white.png" class="abs-tr m-6 h-24 opacity-90" alt="KCD Czech & Slovak" />

<div class="abs-bl m-6 text-sm opacity-75">
  KCD Czech-Slovak 2026 · #SREAgent · #KCDCzechSlovak2026
</div>

