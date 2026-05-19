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
  <strong>David Pech</strong> — Platform / SRE, Kubernetes, AWS, Postgres
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

<!--
The 30-second version. KubeCon Atlanta / Paris this year: every other booth had some
flavor of "AI SRE" or "autonomous incident responder". The pitch is always identical:
an alert fires, the agent investigates, the agent fixes the issue, you don't even
wake up. The next slide is the same layout — same boxes, same positions — but the
honest, broader version. So you can mentally flip between the marketing pitch and the
trench reality.
-->

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

<!--
Same picture, honest version. Left column: KubeCon was an MCP-fest. Trust boundaries
got zero airtime. Almost every "production" demo was on a hand-crafted scenario.
Right column: the pitch is the same, but read the asterisks. "Investigates" only works
on systems the agent has been *told* exist. "Fixes" means a PR — and your on-call still
has to merge it. The realistic win is not "wake up to a green dashboard". The realistic
win is "the first 20 minutes of context-gathering on every incident drops to 2".
That's still huge — but it's a different sales pitch.
-->

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

<div class="grid grid-cols-2 gap-6 mt-4 text-sm">

<div>

- internal "Product" <- the most important part

TODO: make this slide nice, do NOT ADD more text

Who is it for?
- We are not sure
- Ops + maybe: DevOps, Developer, Managers...

What it should do?
- We don't know
- Investigate, research, maybe: fix things? Do we really want that?

</div>

</div>

---
layout: default
---

# Technicals

<div class="grid grid-cols-2 gap-6 mt-4 text-sm">

<div>

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

</div>

</div>

---
layout: default
---

# Wrong Approach

<div class="grid grid-cols-2 gap-6 mt-4 text-sm">

<div>

Vendor are selling the tool: `run agent on your alerts`

TODO: ai magic will happen

Our `ops-responder-agent`:
- could sell you fresh bread over Slack with a different context...
- can be replaced with Gemini Enterprise or any other in a month

</div>

</div>

---
layout: default
---

# What Can You get Without Context

<div class="grid grid-cols-2 gap-6 mt-4 text-sm">

<div>

TODO: pagerduty-event.png

</div>

</div>

---
layout: default
---

# Guess Work

<div class="grid grid-cols-2 gap-6 mt-4 text-sm">

<div>

TODO: pagerduty-sre-agent.png

Resume: Not bad given how few context it has.

Useful: absolutely not.

@PagerDuty booth discussion on KubeCon NA 2025: "Can we add more context?" "No."
(but it might have changed since...)

</div>

</div>

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

Our approach:
- move from some proprietary wiki to Markdown
- we needed to recreate wiki from scratch

Typically 30 - 110 tool uses (Grep|Read|Glob) for single prompt



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

Alert A.

@ops-responder-agent - find the definition of the alert

@ops-responder-agent - based on the alert definition do X

---
layout: two-cols
---

# Problem: How to Get Result in Reasonable time

TODO: timeout

Highly model-dependant.

TODO: screens shot from context

It doesn't work well.

---
layout: two-cols
---

# Slack Output

- no formatting
- have a script replace .md / something to `Block Kit`
- explain that in a context

TODO: screenshot of context

---
layout: two-cols
---

# Problem: Output Gets Polluted

Thinking: off

"Extended thinking"

TODO: screenshot of broken output



TODO: screenshot of context - YOU MUST NOT

---
layout: two-cols
---

# Problem: MCP on top of API

- MCP tools are not aligned to human promptingo

Our Approach:
- `/init`-like instruction for such MCPs

TODO: netbox mcp image


---
layout: two-cols
---

# Problem: MCP Offer Too Wide Data

- Superadmin token will give you all the teams in your company
- You need only those that have category 'ops'

TODO: mcp alerting

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

# Build it yourself, or buy a platform? 🛒

<div class="grid grid-cols-3 gap-4 mt-4 text-sm">

<div class="kcd-card">

### 🛍️ Buy a platform
- Fast to demo
- Slack app + webhooks + nice UI
- Pre-baked integrations (PagerDuty, Datadog, GitHub)
- ❌ Your **local** MCPs / scripts / clusters? Up to them.
- ❌ Pricing tied to seats or alerts — both grow

</div>

<div class="kcd-card">

### 🧰 Build with an SDK
**Our choice: Claude Agent SDK**
- ✅ Reuse everything you already run locally
  - `kubectl`, `gh`, `psql`, internal CLIs
- ✅ One auth boundary: the dev's laptop / a sandboxed pod
- ⚠️ Childhood diseases (see right column)

</div>

<div class="kcd-card">

### 🧪 Roll your own loop
- LangChain / LangGraph / your own
- Total control, total surface area
- You will rewrite the tool-router 3 times
- ❌ You will **also** rewrite the retry/timeout/loop-detector

</div>

</div>

<div class="mt-5">

### Real "childhood diseases" we hit with the Agent SDK

<div class="grid grid-cols-2 gap-3 text-sm mt-2">

<div class="kcd-card kcd-card-warn">
  🐚 We ended up <strong>parsing bash commands ourselves</strong> — to gate `rm`, `kubectl delete`, `helm uninstall` before exec.
</div>
<div class="kcd-card kcd-card-warn">
  ⏱️ <strong>60 s startup timeout</strong> for MCP servers — fine locally, weird on a cold container with cold DNS.
</div>
<div class="kcd-card kcd-card-warn">
  🗂️ Some MCP servers <strong>log to FS dirs</strong> on the container — discovered by running out of disk.
</div>
<div class="kcd-card kcd-card-warn">
  🧵 <strong>Sessions ≠ Slack threads.</strong> We had to map thread_ts → session_id ourselves to keep context.
</div>

</div>

</div>

<div class="kcd-source">
  Honest answer: "platform vs. SDK" depends on whether you have local MCPs/scripts you want to reuse. We did, so SDK won.
</div>

<!--
The question every team asks: do we buy one of those vendor platforms, or do we build?
Honest answer: it depends on whether you already have a pile of local tooling — CLIs,
scripts, internal MCP servers — that you want the agent to reuse. We did. So we picked
the Claude Agent SDK and stayed on-prem. The bottom row is the real "told you so"
list — things the SDK got wrong-ish that we had to wrap. Watch out for: bash command
parsing (don't trust the LLM not to `rm -rf`), 60-second MCP startup timeout, MCP
servers writing logs to arbitrary filesystem paths, and — biggest one — Slack thread
≠ agent session; we had to maintain that mapping ourselves.
-->

---
layout: default
---

# Slack integration is the hard part 💬

<div class="grid grid-cols-2 gap-6 mt-4">

<div>

### What we wanted

- React to `@agent` (and only `@agent`)
- Understand the **whole thread**, not just the mention
- Notice activity on related channels (`#incidents`, `#alerts`, `#releases`)
- Keep ~1 day of channel history as **background context**

### What the Slack API gives you

- One event at a time
- Thread context only if you ask, paginated, rate-limited
- `bot.user.id` ≠ `@agent` mention in some scopes
- Conversation lists require admin scopes most platforms don't grant

</div>

<div>

### Two paths we tried

<div class="kcd-card mt-2">
  <strong>A. "Vibe-coded" listener</strong><br/>
  Custom bot online 24/7, keeps a rolling 1-day buffer per channel,
  injects into a structured knowledge base for the agent.<br/>
  <em class="opacity-80">Pros: full context. Cons: you own a stateful service that must never lose Slack tokens.</em>
</div>

<div class="kcd-card mt-2">
  <strong>B. Offer Slack as a tool (MCP)</strong><br/>
  Agent calls a Slack MCP server on-demand to fetch what it needs.<br/>
  <em class="opacity-80">Pros: stateless, fewer scopes. Cons: every question = N API calls, rate-limit roulette.</em>
</div>

<div class="mt-4 kcd-card kcd-card-danger text-sm">
  ⚠️ <strong>Loop guard first</strong>: agent must <em>never</em> react to its own messages, or to a thread it already replied in within X seconds. Ours fired twice before we added the cooldown.
</div>

</div>

</div>

<!--
Slack is where this lives or dies. We wanted the agent to react only to @agent mentions,
but ALSO be aware of related channels — `#incidents`, `#alerts`, `#releases` — so it
can spot "oh wait, there's a planned migration happening right now". The Slack API
makes that surprisingly painful: events come one at a time, thread context costs
extra calls, and the scopes you'd need to passively read a channel are admin-only on
most workspaces. We tried two designs. Plan A: a custom 24/7 listener that keeps a
day of rolling history per channel and injects it into a knowledge base. Plan B: a
Slack MCP that the agent calls when it needs to look. We're currently running A for a
few key channels and B for everything else. The single most important guard, no
matter which path: the agent must never react to its own messages, and must
cooldown on threads where it just replied. We learned this the way you'd expect.
-->

---
layout: default
---

# Tools vs. MCP servers vs. local bash 🐚

<div class="grid grid-cols-3 gap-4 mt-4 text-sm">

<div class="kcd-card kcd-card-ok">


</div>

<div class="kcd-card">

### 🥈 Native tools (function calls)
- Strongly typed inputs, JSON in / JSON out
- LLM picks the right one ~most of the time
- ⚠️ Brittle once you have **30+** of them
- ⚠️ Tool descriptions become a context budget problem

</div>

<div class="kcd-card kcd-card-warn">

### 🥉 MCP servers
- Spec is great, ergonomics still bumpy
- Spawns a process; cold-start adds latency
- LLM sometimes "forgets" an MCP exists between turns
- Schema drift between MCP versions = silent failures

</div>

</div>

<div class="mt-6 kcd-card text-base">
  💡 Counter-intuitive finding: for many tasks, Claude was <strong>noticeably better</strong> at
  <code>ls</code> / <code>grep</code> / <code>cat</code> in a sandboxed dir than at calling a custom tool
  that did the same thing. The LLM has read more bash than your API.
</div>

<div class="mt-3 text-sm opacity-80">
  ⚠️ This is partly a <em>2025</em> observation. Models since late-'25 got noticeably better at
  many-tool routing — so this advice will rot. Re-benchmark when you upgrade models.
</div>

<div class="kcd-source">
  We compared: read-only repo of YAML manifests via (a) <code>bash+grep</code>, (b) a typed `search_manifest` tool, (c) an MCP server. <code>bash+grep</code> won on quality and latency.
</div>

<!--
The hottest take in the talk. We benchmarked the same task three ways: read-only repo
of Kubernetes manifests, agent has to find which deployment owns a specific config
key. Path A: give it bash in a sandbox. Path B: give it a typed `search_manifest`
function. Path C: an MCP server doing the same. Bash won on quality AND latency.
The LLM has read more bash than your custom API. Tools and MCPs are still useful —
especially when the action is dangerous, or the data is huge — but don't reach for an
MCP server before you've tried "let it grep". Caveat: this is a 2025 observation, and
the newest models are much better at many-tool routing. Re-test when you upgrade.
-->

---
layout: default
---

# General recon vs. research 🔍

<div class="opacity-50 text-sm mt-8">[ TODO: fill in — quick recon vs. deep-dive research ]</div>

<!--
TODO
-->

---
layout: default
---

# Research: "are we vulnerable?" 🛡️

<div class="opacity-50 text-sm mt-8">[ TODO: fill in — CVE / advisory research, SBOM cross-check, blast-radius ]</div>

<!--
TODO
-->

---
layout: default
---

# Recurring & historical fixes 🔁

<div class="opacity-50 text-sm mt-8">[ TODO: fill in — how the agent uses history of past incidents & fixes ]</div>

<!--
TODO
-->

---
layout: default
---

# Slack problems, continued 💬

<div class="opacity-50 text-sm mt-8">[ TODO: fill in — more Slack edge cases beyond the earlier slide ]</div>

<!--
TODO
-->

---
layout: default
---

# IDs vs. human-readable — provide links 🔗

<div class="opacity-50 text-sm mt-8">[ TODO: fill in — surface IDs/UUIDs as clickable links, not raw strings ]</div>

<!--
TODO
-->

---
layout: default
---

# Evaluating human responses 🤦

<div class="opacity-50 text-sm mt-8">[ TODO: fill in — read emoji reactions (facepalm 🤦, 👍, ❌) as signal ]</div>

<!--
TODO
-->

---
layout: default
---

# Security: secrets & context 🔒

<div class="opacity-50 text-sm mt-8">[ TODO: fill in — never post passwords, sanitize context, redaction ]</div>

<!--
TODO
-->

---
layout: default
---

# MCPs in practice (incl. security review) 🧩

<div class="opacity-50 text-sm mt-8">[ TODO: fill in — MCP server pitfalls + the security-review MCP example ]</div>

<!--
TODO
-->

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

Save your job.

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
    <span class="text-base font-mono opacity-80">github.com/depeche-io</span>
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

