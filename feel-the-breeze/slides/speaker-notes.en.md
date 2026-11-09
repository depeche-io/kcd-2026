# Feel the Breeze — English speaker script

Kubernetes On Edge Day 2026 · Salt Lake City · November 9, 2026.

This script follows the current 17-slide deck, including the worldwide region comparison. Use it as a rehearsal script and adapt the phrasing to your own voice. Text in square brackets is a stage direction and is not spoken. The two introductions are labelled by speaker; the rest uses “we” so either presenter can deliver it.

Slides 11 and 12 are reserved for your own live-demo narration. Slide 17 is an optional backup introduction. Read either this English version or the [Czech version](speaker-notes.cs.md) during rehearsal; they are alternative versions of the same talk.

The main script contains approximately 1,850 spoken words: allow roughly **13–16 minutes**, plus the live demo, audience interaction and questions. Practise once aloud to establish your own timing.

The central message is: **We can do the same useful work with fewer emissions by measuring its energy use and choosing when and where flexible work runs.** Data sources and calculation assumptions are in the [deck README](README.md#data-and-assumptions). The numerical examples retain the deck’s distinction between measurements, models and projections.

## 01 — Feel the Breeze

Hi everyone, and welcome to Feel the Breeze at Kubernetes On Edge Day. We’re David and Petr, and we brought a solar panel, a Raspberry Pi, and a fan to our session.

There is a practical reason for the hardware. Energy is usually hidden behind our cloud APIs. We create a deployment, choose a replica count, and see a bill at the end of the month. The electricity behind those decisions is much less visible.

Today we want to connect those two worlds. Our main idea is simple: we can do the same useful work with fewer emissions if we understand its energy use and choose when and where flexible work runs.

We’ll start with the motivation, look at the measurements, and then make a control loop visible on stage.

## 02 — Who

**David:** I’m David Pech. I enjoy Kubernetes, automation, and understanding how all the pieces of a platform fit together.

**Petr:** And I’m Petr Rais. I’m a software engineer with an interest in DevOps and the connection between applications and the infrastructure running them.

**Either speaker:** This project gives us a way to explore that connection with something we can actually touch. We use familiar cloud native tools, but the output is a physical device responding to a changing energy signal.

Let’s begin with an energy decision that everyone in this room has already made.

## 03 — How did you get here?

Quick show of hands: who flew here? Who drove? And who took the train from the airport?

[Pause for a show of hands.]

We already understand that getting from one place to another can have a very different carbon footprint depending on how we travel. These bars put some approximate numbers around that intuition.

They use standard factors and rounded distances. The train figure uses a US average, and the flight figures exclude additional non-CO₂ climate effects. Treat them as examples of scale rather than personal travel calculations.

Now look at the pod example. If we allocate five watts to an always-on workload, that becomes about forty-four kilowatt-hours over a year. Using the grid factor shown for Salt Lake City, that is roughly twenty-five kilograms of CO₂ equivalent, before facility overhead.

Five watts is an assumption here. The useful question is: how many small, always-on allocations do we have across our clusters, and how much useful work are they doing?

## 04 — Even hyperscalers hit the wall

This becomes a physical constraint at data-centre scale.

The IEA’s 2026 report puts global data-centre electricity use at about four hundred and eighty-five terawatt-hours in 2025. Its projection for 2030 is about nine hundred and fifty. That second number is a forecast, and it comes with uncertainty, but it shows the scale of the challenge.

More compute also needs grid connections, transformers, permits, and a place in the local energy system. Those things have different lead times from deploying software.

We can’t solve all of that from a Kubernetes manifest. We can, however, reduce wasted capacity and make suitable workloads more flexible.

That is our part of the problem: how much work really needs to run continuously, how efficiently does it run, and how much freedom do we have over its timing and location?

To explore those questions, we built a small system we can bring on stage.

## 05 — Kubernetes that fits in your pocket

Our edge cluster runs k0s on a Raspberry Pi with two gigabytes of RAM. It gives us the Kubernetes API and the tools we already know on a small physical device.

We keep Argo CD, Prometheus, and Grafana at HQ, so we don’t have to duplicate those services on the Pi.

The setup is declared in our feel-the-breeze project repository, linked at the bottom of this slide. The Pi and HQ configuration lives in its pi and hq directories. We can rebuild the device and sync its workloads, while restoring device credentials separately.

For this talk, the Pi is our experimental platform. Its small size makes the relationship between software and physical hardware easy to see. The actual memory and power budgets still need to be measured on the hardware we use.

Here is how we manage it from the central cluster.

## 06 — One HQ, N edge clusters

Argo CD at HQ connects to the edge cluster’s Kubernetes API and manages the declared applications there. Prometheus gathers the edge metrics, and Grafana gives us a place to inspect them.

The diagram shows how this pattern can extend to multiple sites. ApplicationSets can generate applications for registered clusters, while the central services are shared across the setup.

We use one physical edge cluster for this demonstration. The multiple sites in the diagram illustrate the management pattern.

The important connection to our topic is observability: we need to see what a workload is doing and then change its behaviour through a repeatable deployment process.

That gives us the management loop. Next, we need an energy signal we can interpret.

## 07 — Project Kepler

Kepler exports energy-related metrics that help us connect workloads to hardware consumption.

The current upstream architecture shown here uses hardware energy readings and CPU-time information to attribute consumption to workloads. Its design has changed from the older eBPF and model-server architecture, so the version and documentation matter.

The distinction to keep in mind is attribution. A per-pod power value is a share assigned to that workload using a method. It is not an independent physical meter attached to every pod.

Our Pi demonstration uses an older chart, and its Kepler workload values are model estimates because the relevant hardware counters are unavailable on this setup. The USB tester measures solar input separately.

Both signals can be useful, provided we explain what each represents. Before using a number to make a decision, we should know its source, its hardware boundary, and how it was assigned to the workload.

## 08 — Watts are a signal. Work is the denominator.

There are three steps here: measure, attribute, and compare.

Watts describe power at a moment in time. To understand the energy used by a job, we need power over its duration. A lower power reading can still lead to higher energy use if the job takes much longer.

Then we need to understand the boundary. Are we looking at a CPU package, a whole node, or a larger system? How is consumption shared between workloads? What happens to the idle baseline?

Finally, compare the same useful result: a completed job, a number of successful requests, or a processed dataset, under the same service requirements.

Operational emissions come from energy multiplied by grid carbon intensity. A fuller accounting also includes the embodied emissions of the hardware.

That is why our goal is energy and emissions per useful result. It gives us a meaningful way to assess an optimisation.

## 09 — Move the work, keep the deadline

Let’s make the timing decision concrete.

Imagine a job that uses one hundred kilowatt-hours. At five hundred grams of CO₂ equivalent per kilowatt-hour, its operational emissions are fifty kilograms. If the same job uses the same energy during a window with a factor of one hundred grams, the result is ten kilograms.

That is an eighty-percent reduction in this hypothetical example. It demonstrates the arithmetic; it is not a measured result from our demo.

The practical question is whether the workload has that flexibility. Batch analytics, media processing, and non-urgent backups may have room to move. We still need a deadline, a maximum queue age, and a plan for missing or stale signals.

One implementation option is the Carbon Aware KEDA Operator. It can adjust the allowed replica ceiling from an external carbon forecast, while KEDA continues to determine workload demand.

Success means completing the same work on time, including any overhead introduced by the change.

## 10 — CNCF Environmental Sustainability

There is a community working on these questions, and it is a useful place to share experiments.

The former Environmental Sustainability TAG continues as a Technical Community Group. Its work includes energy and carbon metrics, tools such as Kepler, and sharing practical experience.

Green Reviews now sits under TAG Operational Resilience. It supports structured reviews of the resource and energy footprint of cloud native projects.

You can contribute by sharing a repeatable experiment: what you ran, which hardware you used, how you measured it, and what changed.

That level of detail helps other people reproduce the result and understand where it applies. Our hardware setup is one way to start that conversation. Let’s put the control loop on stage.

## 11 — Demo time!

[Live demo. Use your own narration; no prepared speech.]

## 12 — The solar + fan control loop

[Live demo and architecture explanation. Use your own narration; no prepared speech.]

## 13 — Key takeaways

Our setup brings together three ideas.

First, a small edge device can participate in a familiar Kubernetes management pattern. That makes physical experiments accessible with tools we already use.

Second, power and energy can become part of our observability. To make those metrics useful, we need to explain sensor coverage, attribution, and estimates, and connect them to completed work.

Third, flexible workloads give us another decision to make: when and where should the work run, while still meeting its deadline and service objectives?

The hardware demonstrates a response to renewable availability. Establishing an actual emissions reduction would require a suitable carbon signal and a before-and-after comparison for the same useful work.

We’ve talked about changing the time. Before we finish, let’s look at the location decision on a worldwide scale.

## 14 — Same VM, different region

This comparison covers six continents. Each row uses the same assumed annual energy and changes the regional grid factor.

The VM label gives us a concrete workload size, but the eighty-watt allocation and facility overhead are modelling assumptions. These are not measured power values for that machine type.

Using Google’s published 2025 grid factors, our model gives about twelve kilograms of CO₂ equivalent in Paris, four hundred and thirty-eight in Salt Lake City, and four hundred and ninety-four in Johannesburg. That is roughly a forty-fold spread between the lowest and highest examples on this slide.

These are annual, location-based grid averages. They serve a different purpose from an hourly scheduling forecast or a customer’s reported cloud footprint.

The decision also has to satisfy latency, capacity, and data residency requirements. Within those constraints, location can be a substantial part of the calculation.

The next step is to test that idea on a workload you understand.

## 15 — Try it this week

Start with one supported node and one workload. Check which energy sensors are available, then confirm what Kepler actually exports on that setup.

The command here is the current upstream installation path. Our Pi demo keeps its older chart and dashboard together, so take care to match metrics and documentation to the version you deploy.

Choose a workload with a measurable output and some scheduling flexibility. Record its energy use, the work completed, its runtime, and whether it met its service requirements.

Then change one thing: perhaps the execution window or an eligible region. Repeat the same work and compare the results, including any extra transfers, restarts, or waiting overhead.

If you want to reduce the node’s idle baseline as well, check whether the infrastructure can consolidate and scale down.

One repeatable before-and-after result gives you evidence for deciding what to try next.

## 16 — Thank you

If you remember one idea from today, make it this: measure the energy needed for useful work, then use the flexibility you have over when and where it runs.

The QR code links to the repository with the demo and slides. The calculation assumptions and sources are there too, so you can inspect them or adapt the experiment.

Thank you for joining us. We’d love to hear which workload you would try this with, and what constraints you would need to respect.

And if you’d like a closer look at the hardware, come and feel the breeze.

[Pause for questions. End of the main talk; advance to slide 17 only if needed.]

## 17 — Backup Video

[Optional. Use this only if you need the recording during the demo. Afterwards, return to the explanation or continue with slide 13.]

We have a recording of the same setup, so we can still show the behaviour we want to discuss. As you watch, look for the connection between the changing input signal, the scaling decision, and the physical device.
