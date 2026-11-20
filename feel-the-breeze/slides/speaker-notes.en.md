# Feel the Breeze — English speaker script

Techmeetup Ostrava 2026 · Ostrava-Poruba · November 20, 2026.

This script follows the current 20-slide [PDF deck](feel-the-breeze.pdf), including the scale of 1 TWh, a week of Great Britain grid carbon intensity, and the worldwide region comparison. Use it as a rehearsal script and adapt the phrasing to your own voice. Text in square brackets is a stage direction and is not spoken. The two introductions are labelled by speaker; the rest uses “we” so either presenter can deliver it.

Slides 13 and 14 are reserved for your own live-demo narration. Slide 15 asks an audience question; slide 16 reveals the answer. Slide 20 is an optional backup introduction. Read either this English version or the [Czech version](speaker-notes.cs.md) during rehearsal; they are alternative versions of the same talk.

The main script contains approximately 2,700 spoken words: allow roughly **19–23 minutes** at 120–140 words per minute, plus the live demo, audience interaction and questions. Practise once aloud to establish your own timing.

The central message is: **We can do the same useful work with fewer emissions by measuring its energy use and choosing when and where flexible work runs.** Sources appear on the slides and in the [deck source](slides.md); further calculation details are in the [deck README](README.md#data-and-assumptions). The numerical examples retain the deck’s distinction between measurements, models and projections.

## 01 — Feel the Breeze

Hi everyone, and welcome to Feel the Breeze at Techmeetup Ostrava. We’re David and Petr, and we brought a solar panel, a Raspberry Pi, and a fan to our session.

There is a practical reason for the hardware. Energy is usually hidden behind our cloud APIs. We create a deployment, choose a replica count, and see a bill at the end of the month. The electricity behind those decisions is much less visible.

Today we want to connect those two worlds. Our main idea is simple: we can do the same useful work with fewer emissions if we understand its energy use and choose when and where flexible work runs.

We’ll start with the motivation, look at the measurements, and then make a control loop visible on stage.

## 02 — Who

**David:** I’m David Pech. I enjoy Kubernetes, automation, and understanding how all the pieces of a platform fit together.

**Petr:** And I’m Petr Rais. I’m a software engineer with an interest in DevOps and the connection between applications and the infrastructure running them.

**Either speaker:** This project gives us a way to explore that connection with something we can actually touch. We use familiar cloud native tools, but the output is a physical device responding to a changing energy signal.

Let’s begin with an energy decision that everyone in this room has already made.

## 03 — How did you get here?

Quick show of hands: who drove to Ostrava? Who took a train or coach? And who arrived by tram or on foot?

[Pause for a show of hands.]

We already understand that getting from one place to another can have a different carbon footprint depending on how we travel. These bars put some approximate numbers around that intuition using journeys to Ostrava.

For example, the Prague routes assume about three hundred and seventy kilometres by car or three hundred and fifty by train. We also show a coach from Brno and a short tram journey from Svinov to VŠB. Distances are rounded, and the calculation uses UK DESNZ reference emission factors. These are not measured Czech operator emissions or estimates for a particular service. Walking counts zero direct operational emissions here.

Now look at the pod example. If we allocate five watts to an always-on workload, that becomes about forty-four kilowatt-hours over a year. Using MPO's Czech electricity generation factor for 2025 gives roughly fourteen and a half kilograms of CO₂, before facility overhead. It is a national production proxy rather than a measurement of Ostrava's electricity consumption.

Five watts is an assumption here. The useful question is: how many small, always-on allocations do we have across our clusters, and how much useful work are they doing?


## 04 — Even hyperscalers hit the wall

This becomes a physical constraint at data-centre scale.

The IEA’s 2026 report puts global data-centre electricity use at about four hundred and eighty-five terawatt-hours in 2025, growing seventeen percent year on year. Its projection for 2030 is about nine hundred and fifty terawatt-hours, roughly three percent of global electricity demand. That second number is a forecast, and it comes with uncertainty, but it shows the scale of the challenge.

More compute also needs grid connections, transformers, permits, and a place in the local energy system. Those things have different lead times from deploying software.

Local opposition matters too. The August Heatmap and Embold poll on this slide reports seventy-five percent of US voters opposing a data centre near them, up from forty-two percent a year earlier. A separate March Gallup poll reports seventy-one percent opposing a local data centre, compared with fifty-three percent opposing a local nuclear plant. These are different surveys; together they illustrate the social constraints on construction as well.

We can’t solve all of that from a Kubernetes manifest. We can, however, reduce wasted capacity and make suitable workloads more flexible.

That is our part of the problem: how much work really needs to run continuously, how efficiently does it run, and how much freedom do we have over its timing and location?

Before we look at our small setup, let’s give those terawatt-hours a more concrete scale.

## 05 — How much is 1 TWh?

One terawatt-hour is a billion kilowatt-hours. Data centres used about four hundred and eighty-five of them in 2025. But what does one look like?

The first comparison is about five hundred and thirty Falcon 9 launches. Here we are comparing the chemical energy in the fuel, about one point nine gigawatt-hours per launch. That is neither the rocket’s electricity consumption nor the energy actually converted into motion.

For a desktop PC assumed to draw one hundred watts, it is ten billion hours of operation. That is roughly one point one million PCs running continuously for a year.

The third comparison uses published figures for AI text queries: zero point two four to zero point three four watt-hours each. At those values, one terawatt-hour represents roughly three to four trillion queries. These are a Gemini median and a ChatGPT average from different sources, rather than a universal energy cost for every query.

One query is tiny. At trillions of repetitions, the energy per task and the electricity supplying it both matter. Let’s look at how we manage workloads at the edge.

## 06 — Efficient edge fleet: one HQ, N edge clusters

We call our central cluster HQ. Argo CD there connects to the edge cluster’s Kubernetes API and manages the declared applications. We register the edge using a ServiceAccount token; it needs no separate Argo CD agent. HQ Prometheus gathers edge metrics through the API-server proxy, and Grafana gives us a place to inspect them.

The diagram shows how this pattern can extend to multiple sites. ApplicationSets can generate applications for registered clusters, while the central services are shared across the setup.

We use one physical edge cluster for this demonstration. The multiple sites in the diagram illustrate the management pattern.

The important connection to our topic is observability: we need to see what a workload is doing and then change its behaviour through a repeatable deployment process.

Sharing the central services spreads their overhead across sites. We can also suspend eligible workloads outside the hours they are needed. Now let’s look at one concrete device in that architecture.

## 07 — Kubernetes that fits in your pocket

Our edge cluster runs k0s on a Raspberry Pi 4: ARM64, with two gigabytes of RAM. It runs both the control plane and worker, giving us the Kubernetes API and the tools we already know on a small physical device.

We keep Argo CD, Prometheus, and Grafana at HQ, so we don’t have to duplicate those services on the Pi.

The setup is declared in our feel-the-breeze project repository, linked at the bottom of this slide. The Pi and HQ configuration lives in its pi and hq directories. Rebuilding starts with flashing Ubuntu and applying cloud-init. We then install k0s, register the device at HQ, and let Argo CD sync the declared workloads. Device credentials are restored separately.

For this talk, the Pi is our experimental platform. Its small size makes the relationship between software and physical hardware easy to see. The actual memory and power budgets still need to be measured on the hardware we use.

That gives us the management loop. Next, we need an energy signal we can interpret.

## 08 — Project Kepler

Kepler exports energy-related metrics that help us connect workloads to hardware consumption.

The slide lists upstream version zero point thirteen point zero, released on November sixth, 2026. This architecture uses hardware energy readings and CPU-time information from procfs and sysfs to attribute consumption to workloads. It supports RAPL, with experimental hwmon, GPU, and Redfish support. It requires no eBPF capability; the eBPF and model-server design is legacy, through version zero point nine. Version zero point twelve added ARM64 images, hwmon fallback, and MIG attribution through DCGM. The version and documentation matter.

The distinction to keep in mind is attribution. A per-pod power value is a share assigned to that workload using a method. It is not an independent physical meter attached to every pod.

Our Pi demonstration uses the older Helm chart zero point five point ten, and its Kepler workload values are model estimates because the relevant hardware counters are unavailable on this setup. The USB tester measures solar input separately.

Both signals can be useful, provided we explain what each represents. Before using a number to make a decision, we should know its source, its hardware boundary, and how it was assigned to the workload.

## 09 — The same kWh is not the same carbon

Energy use is only one part of the calculation. Grid carbon intensity tells us the emissions associated with each kilowatt-hour, and it changes over time.

This is a real week on the Great Britain grid, from October twenty-sixth to November first, 2026. The data comes from the NESO Carbon Intensity API. The chart shows hourly means of half-hour values in UTC, in grams of CO₂ per kilowatt-hour.

On a windy Tuesday, the value fell to about fifty-two grams. On Thursday morning, with less wind and more gas, it reached two hundred and thirty-two. That is roughly a four-and-a-half-fold difference within one week for the same kilowatt-hour.

The diagram on the right shows pumped-storage hydro. During cleaner, cheaper hours, it pumps water uphill. At peaks, it releases that water to generate electricity. A flexible workload can use better hours in a similar way by moving its execution. The computation shifts demand in time rather than storing electricity.

This is a historical trace, not a forecast for today’s demo. Scheduling ahead needs an appropriate current signal and constraints for the particular workload. First, though, we need to define what we compare.

## 10 — Watts are a signal. Work is the denominator.

There are three steps here: measure, attribute, and compare.

Watts describe power at a moment in time. To understand the energy used by a job, we need power over its duration. A lower power reading can still lead to higher energy use if the job takes much longer.

Then we need to understand the boundary. Are we looking at a CPU package, a whole node, or a larger system? How is consumption shared between workloads? What happens to the idle baseline?

Finally, compare the same useful result: a completed job, a number of successful requests, or a processed dataset, under the same service requirements.

Operational emissions come from energy multiplied by grid carbon intensity. A fuller accounting also includes the embodied emissions of the hardware.

That is why our goal is energy and emissions per useful result. It gives us a meaningful way to assess an optimisation.

## 11 — Move the work, keep the deadline

Let’s make the timing decision concrete.

Imagine a job that uses one hundred kilowatt-hours. At five hundred grams of CO₂ equivalent per kilowatt-hour, its operational emissions are fifty kilograms. If the same job uses the same energy during a window with a factor of one hundred grams, the result is ten kilograms.

That is an eighty-percent reduction in this hypothetical example. It demonstrates the arithmetic; it is not a measured result from our demo.

The practical question is whether the workload has that flexibility. Batch analytics, CI, media processing, and non-urgent backups may have room to move. We still need a deadline, a maximum queue age, service objectives, data locality rules, and a plan for missing or stale signals.

One implementation option is the Carbon Aware KEDA Operator. It can adjust the allowed replica ceiling from an external carbon forecast, while KEDA continues to determine workload demand.

Success means completing the same work on time, including any overhead introduced by the change.

## 12 — CNCF Environmental Sustainability

There is a community working on these questions, and it is a useful place to share experiments.

The former Environmental Sustainability TAG continues as a Technical Community Group. Its work includes energy and carbon metrics, tools such as Kepler, and sharing practical experience.

You can join through Cloud Native Sustainability Month or the #tcg-environmental-sustainability channel on CNCF Slack. The slide links to the current meetings.

Green Reviews now sits under TAG Operational Resilience. It supports structured reviews of the resource and energy footprint of cloud native projects.

You can contribute by sharing a repeatable experiment: what you ran, which hardware you used, how you measured it, and what changed.

That level of detail helps other people reproduce the result and understand where it applies. Our hardware setup is one way to start that conversation. Let’s put the control loop on stage.

## 13 — Demo time!

[Live demo. Use your own narration; no prepared speech.]

## 14 — The solar + fan control loop

[Live demo and architecture explanation. Use your own narration; no prepared speech.]

## 15 — How would you cut your cloud VM’s CO₂?

We have just shown a response to solar availability. Now imagine one cloud VM running continuously. Where would you start to reduce its emissions?

Would you reduce its RAM? Choose a smaller machine? Move from x86 to ARM? Turn it off outside work hours, pack more pods onto each node, or change its region?

[Take two or three answers. Keep the next slide hidden for now.]

Each option can make sense. Memory and unused cores draw power. A forty-hour working week leaves another hundred and twenty-eight hours when the machine might be unnecessary. Consolidation can let us turn entire nodes off. For an architecture change, we need to measure how much of the same work we actually complete per unit of energy.

So we have options that change energy consumption, and options that change the emissions per kilowatt-hour. Which one could make roughly a forty-fold difference in our example?

[Pause briefly for guesses, then advance to the region comparison.]

## 16 — Same VM, different region

Here is the answer: region. This comparison covers six continents. Each row uses the same assumed annual energy and changes the regional grid factor.

We use the label n4-standard-8: eight virtual CPUs and thirty-two gigabytes of RAM. The eighty-watt allocation and PUE of one point one are modelling assumptions. Together they give about seven hundred and seventy-one kilowatt-hours a year, including that overhead. These are not measured power values for that machine type.

Using Google’s published 2025 grid factors, our model gives about twelve kilograms of CO₂ equivalent in Paris, four hundred and thirty-eight in Salt Lake City, and four hundred and ninety-four in Johannesburg. That is roughly a forty-fold spread between the lowest and highest examples on this slide.

These are annual, location-based grid averages. They serve a different purpose from the hourly Great Britain trace, a scheduling forecast, or a customer’s reported cloud footprint. The model excludes embodied hardware emissions, storage, and networking.

The decision also has to satisfy latency, capacity, and data residency requirements. Within those constraints, location can be a substantial part of the calculation.

That brings us to the main takeaways from today.

## 17 — Key takeaways

There are four points to take away.

First, a small edge device can participate in a familiar Kubernetes management pattern. k0s at the edge, Argo CD at HQ, and shared Prometheus form a practical pattern for managing multiple sites.

Second, power and energy can become part of our observability. Kepler helps attribute consumption to workloads. To make those metrics useful, we need to explain sensor coverage, attribution, and estimates, and connect them to completed work.

Third, flexible workloads give us another decision to make: when and where should the work run, while still meeting its deadline and service objectives?

Fourth, check your cloud region’s carbon intensity when you deploy. Under the same energy assumptions, our regional comparison showed roughly a forty-fold spread in operational emissions.

The hardware demonstrates a response to renewable availability. Establishing an actual emissions reduction would require a suitable carbon signal and a before-and-after comparison for the same useful work.

How can you start this week?

## 18 — Try it this week

Start with one supported node and one workload. Check which energy sensors are available, then confirm what Kepler actually exports on that setup.

The command here is the current upstream installation path. Our Pi demo keeps its older chart and dashboard together, so take care to match metrics and documentation to the version you deploy. After validation, pin the chart and image versions.

Choose a workload with a measurable output and some scheduling flexibility. Record its energy use, the work completed, its runtime, and whether it met its service requirements.

Then change one thing: perhaps the execution window or an eligible region. Repeat the same work and compare the results, including any extra transfers, restarts, or waiting overhead.

If you want to reduce the node’s idle baseline as well, check whether the infrastructure can consolidate and scale down.

One repeatable before-and-after result gives you evidence for deciding what to try next.

## 19 — Thank you

If you remember one idea from today, make it this: measure the energy needed for useful work, then use the flexibility you have over when and where it runs.

The QR code links to the repository with the demo and slides. The calculation assumptions and sources are there too, so you can inspect them or adapt the experiment.

Thank you for joining us. We’d love to hear which workload you would try this with, and what constraints you would need to respect.

And if you’d like a closer look at the hardware, come and feel the breeze.

[Pause for questions. End of the main talk; advance to slide 20 only if needed.]

## 20 — Backup video

[Optional. Use this only if you need the recording during the demo. Afterwards, return to the explanation on slide 14 or continue with the audience question on slide 15.]

We have a recording of the same setup, so we can still show the behaviour we want to discuss. As you watch, look for the connection between the changing input signal, the scaling decision, and the physical device.
