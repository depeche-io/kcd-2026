


https://kcd-czech-slovak-2026.sessionize.com/session/1196794

We Built an AI Incident Responder. Here's What We Got Wrong.

Everyone is building SRE agents. Most of them are barely junior sysadmins in a trench coat — useful for "how does X work?", useless when PostgreSQL replication is lagging at 3 AM across three datacenters at your specific company with your specific Puppet module.

The work is split into thirds, the first is vibe-coding some Python — the easy one. Second third was prompt engineering — we managed to improve from providing ~80% useful answers to 95%, and the last third is security: 12 defense-in-depth layers (so far while still running read-only with a few MCPs).

Now (95% likely) you can get valuable answer for:
- is this alert recurring? Who was the last responder and what did they do (or say on Slack)?
- what is the impact?
- are we affected by CVE-...
- and many more

We'll walk through what surprised us, what the agent still gets wrong, and why security is the hardest third nobody talks about. No vendor pitch, just a story from the trenches so you can get "more realistic" about this.

