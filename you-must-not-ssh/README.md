

https://cloudnativedayspoland.org/agenda/#talk-you-must-not-ssh-and-other-stories-from-building

"YOU MUST NOT ssh!" and Other Stories from Building Our SRE Agent

Everyone is building SRE agents. Most of them are barely junior sysadmins in a trench coat — useful for "how does X work?", useless when PostgreSQL replication is lagging at 3 AM across three datacenters at your specific company with your specific Puppet module.

We started out obsessing over the tech stack, but after months in production, we learned a few hard truths: The agent framework? It doesn't really matter that much. The LLM model or vendor? Doesn't matter nearly as much as you think. Providing misleading docs? A massive problem. Fear of autonomy? Like handcuffing your agent and getting only 10% out of it. Not unit-testing the context? Likely you'll degrade in the future versions and lose people's trust.

We'll walk through what surprised us, what the agent still gets wrong, and why security is the hardest third nobody talks about. No vendor pitch, just a story from the trenches so you can get "more realistic" about this.
