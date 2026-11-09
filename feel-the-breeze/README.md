# Feel the Breeze: The High-Energy, Fan-Powered Guide to Sustainable Kubernetes

Standard HPA is so totally out now. It scales on CPU but lacks synergy. It doesn’t know if your nodes are sipping clean wind or chugging dirty coal. It’s time to stop "shifting left" and start shifting to the sun!

In this carbon-critical session, we’re ditching boring metrics for Project Kepler. Using eBPF magic—because if it’s not eBPF, is it even Cloud Native?—we’ll expose the raw power consumption of your pods in real-time.

To ground the hype, we’re bringing a physical Solar Panel, lights and a Fan-as-a-Service on stage. Watch the replicas scale to peak intensity the moment our "sun" hits the panel, while industrial fans translate that clean energy into a literal breeze for the front row.

Beyond the hype, come learn how individual pods contribute to your cluster's energy footprint and how to accurately measure it. We’ll showcase a real-time demo of carbon-aware scaling with a few gadgets.


https://kcd-czech-slovak-2026.sessionize.com/session/1196568


# KCD 2026-1 — two-cluster demo

Live demo of two Kubernetes clusters running on a single MacBook:

| Cluster   | Where                          | What runs there                                  |
|-----------|--------------------------------|--------------------------------------------------|
| `factory` | Lima VM, k0s single-node       | Workloads + node-exporter + kube-state-metrics   |
| `hq`      | k3d (k3s in Docker)            | ArgoCD (autopilot) + kube-prometheus-stack + kepler |

ArgoCD on `hq` controls `factory` over the network using a service-account token,
and HQ Prometheus scrapes `factory` workload metrics through the factory API
server's proxy endpoint.

```
            ┌──────────────── macOS host ────────────────┐
            │                                            │
            │   ┌── Lima VM ──┐    ┌──── k3d ─────┐      │
            │   │  k0s        │◄──►│  ArgoCD      │      │
            │   │  factory    │    │  Prometheus  │      │
            │   │             │    │  Kepler      │      │
            │   └─────────────┘    └──────┬───────┘      │
            │                             │              │
            └─────────────────────────────┼──────────────┘
                                          │
                                  cloudflared tunnel
                                          │
                                          ▼
                                   audience browser
```

## Prerequisites

For the Linux laptop and physical Raspberry Pi setup, use the
[Linux + Raspberry Pi procedure](#linux--raspberry-pi) below.

```bash
# Already in the devbox profile:
#   lima, kubectl, helm, argocd, argocd-autopilot

brew install k3d cloudflared
```

A GitHub repo (empty) for the GitOps state. Create one and a fine-grained PAT
with read/write to that repo, then:

```bash
cp .env.example .env
$EDITOR .env       # fill in GIT_REPO + GIT_TOKEN
set -a; source .env; set +a
```

## Run order

```bash
# 1. factory cluster (Lima VM with k0s, ~3 min)
./factory/up.sh

# 2. HQ cluster (k3d + ArgoCD + apps via GitOps, ~3 min)
./hq/up.sh
./hq/bootstrap-argocd.sh

# 3. expose Grafana publicly for the talk
./expose/cloudflared.sh
```

## Tear down

```bash
./hq/down.sh
./factory/down.sh
```

## Linux + Raspberry Pi

### Stop for travel and resume the existing demo

Run from `feel-the-breeze` as the normal laptop user:

```bash
python3 demo_linux.py stop
```

This disables the laptop reconnect/UI services, pauses KEDA at zero replicas,
waits for the fan and LED to acknowledge OFF and their controller pods to exit,
stops the existing HQ Docker containers, then flushes and powers off the Pi.
Wait for the command to finish before unplugging the Pi and other devices.
The containers, SD contents and credentials are retained. `hq/down.sh` deletes
the cluster and is intended for teardown, not travel.

At the destination, power the Pi, meter and both Tuya devices, connect the laptop
to their LAN, then run:

```bash
cd ~/kcd2026/kcd-2026/feel-the-breeze
python3 demo_linux.py start
```

If necessary, enter the sudo password in the terminal for Docker (a launch
without a terminal uses a system authentication dialog). The command starts
the existing HQ server before its worker, authenticates the Pi, discovers Tuya
LAN addresses using keys already on the Pi, refreshes HQ DNS/credentials,
unpauses KEDA, checks all six Pi metric targets and enables the local UI/timer.
Grafana is at <http://localhost:3000>, ArgoCD at <http://localhost:8080>.
Use `PI_HOST=192.168.x.y python3 demo_linux.py start` if mDNS is unavailable.

A different Wi-Fi network requires connecting **Pi, both Tuya devices and the
laptop** to a reachable LAN first. These commands discover changed IP addresses;
they cannot join devices to an unknown Wi-Fi network. Using a private router
with the current SSID/password avoids re-pairing. Re-pairing Tuya devices can
rotate local keys; update their Pi configuration and private backup if that
happens. Changing only `pi/network-config` affects the next flash, not the
already installed Pi. Keep `.local/tuya/` and `.local/pi/` on this laptop.
If you reflash for the new Wi-Fi after a travel shutdown, use `demo_linux.py start`
after powering the Pi: travel shutdown intentionally disabled the laptop timer.

Startup failures leave diagnostics in `.local/demo/last-error.log` when a command
has captured output. Fix the reported network/device/runtime problem and rerun
`start`. A stopped demo intentionally retains KEDA's
[pause annotation](https://keda.sh/docs/2.21/concepts/scaling-deployments/#pausing-autoscaling);
`start` removes it after Pi registration is restored.

### Automatic reflash on the prepared laptop

For subsequent Wi-Fi changes, edit `pi/network-config` and run:

```bash
sudo ./pi/flash_linux.sh /dev/mmcblk0
```

Confirm the actual SD device with `lsblk` before running this command. The flash
script validates the private restore configuration before erasing the card.
It generates a private cloud-init seed from `.local/tuya/devices.env`, embeds
the API and bootstrap services, and arms the laptop reconnect timer only after
the image/configuration have been written and the card unmounted successfully.

On first boot, the Pi waits for NTP clock synchronization, installs the required
packages and pinned k0s version, restores its API, and finds the configured Tuya
devices by ID on the new LAN. It validates their local keys and refreshes IP
addresses/protocol versions. Failed bootstrap attempts retry automatically.

The laptop's `kcd-pi-reconnect.timer` checks for this particular flashed instance
every 30 seconds. It uses a dedicated SSH client key and a pinned, persistent Pi
host identity. Once the Pi finishes bootstrap, it refreshes HQ credentials/DNS,
restarts the controllers in sequence, and restores the physical state from the
meter. Local Grafana/ArgoCD access is also restored automatically. The timer
does no network work until a successful flash has armed it.
It waits for all HQ nodes, Prometheus, the ArgoCD application controller and both
KEDA scalers to be ready, including after the credentials refresh restarts
Prometheus. A reachable Kubernetes API alone does not complete recovery.

Prerequisites: first boot has internet/NTP access; the laptop is logged in and
has a working HQ runtime; Pi and the Tuya devices share a reachable LAN. Tuya
pairing/device IDs and local keys must remain valid. Re-pairing a device can
change its key and requires updating the private backup before flashing again.

One-time preparation on another laptop (already done on the current laptop):

```bash
# Requires Python 3 + PyYAML, ssh-keygen, systemd user services, kubectl and k3d.
python3 pi/install_autoreconnect.py
./pi/flash_linux.sh --prepare-only
```

`--prepare-only` writes no disk and does not arm reconnection. The generated
seed and SSH identities are private files in `.local/pi/`, excluded from Git.
Back up both `.local/pi/` and `.local/tuya/`; the generated SD seed contains
the local device keys and the persistent Pi SSH identity.

Watch the laptop automation:

```bash
systemctl --user status kcd-pi-reconnect.timer
journalctl --user -u kcd-pi-reconnect.service -f
systemctl --user status kcd-grafana.service kcd-argocd.service
```

If bootstrap needs diagnosis before normal SSH trust has been refreshed:

```bash
ssh -i .local/pi/id_ed25519 \
  -o UserKnownHostsFile=.local/pi/known_hosts -o HostKeyAlias=factory-pi.local \
  -o StrictHostKeyChecking=yes ubuntu@factory-pi.local \
  'sudo journalctl -u kcd-bootstrap.service -n 100 --no-pager'
```

The laptop stores detailed failed-command diagnostics privately in
`.local/pi/last-error.log`. Keep the Pi and Tuya devices powered while bootstrap
runs. Recovery after reflashing has been exercised on the physical Pi over the
iPhone hotspot. A new clean flash of the latest fixes has not been repeated.
On a fresh 2 GB Pi, initial image downloads/unpacking can saturate SD I/O;
startup allows up to ten minutes for the six monitoring targets to become healthy.

Bootstrap runs under `cloud-init.target`, after `cloud-final.service`. Its
readiness directory is readable by the SSH user, and the marker must match the
current boot ID. If bootstrap reports `Check device key or version` after Tuya
re-pairing, retrieve the current local keys from the linked Tuya project and
update both `/opt/kcd-tuya/devices.env` and the private `.local/tuya/` backup.
Changing IP addresses alone does not require new keys.

### Manual setup and recovery

This setup uses two clusters: HQ on the laptop and k0s on the physical Pi.
The Linux scripts default to this mode. The legacy factory VM is optional and
requires `ENABLE_FACTORY_VM=1`; its old kubeconfig file alone does not enable it.
The current ArgoCD bootstrap does not require a GitHub token or Git write access.

The laptop, Pi, and Tuya devices must be reachable from each other. Give the Pi
internet access during its initial setup. Check `timedatectl status` on the Pi
before retrying package installation after an APT "not valid yet" error.

On the laptop, with k3d, kubectl, and a working Docker-compatible runtime:

```bash
cd ~/kcd2026/kcd-2026/feel-the-breeze

ssh ubuntu@factory-pi.local 'sudo cloud-init status --wait; sudo k0s kubectl get nodes'
# Check that the node is Ready and resolve any first-boot errors before continuing.

./hq/up_linux.sh
./hq/bootstrap-argocd_linux.sh
./pi/deploy_fnb48p_api.sh
# Configure /opt/kcd-tuya/devices.env on the Pi as described below.
./pi/up_linux.sh
```

`pi/up_linux.sh` refreshes Pi credentials, adds a persistent `coredns-custom`
zone for `factory-pi.local`, deploys the exporters and Kepler, and configures the
two KEDA scalers and Grafana dashboards. Run it again after reflashing the Pi or
changing its IP address. Update any old `factory-pi.local` entry in the laptop's
`/etc/hosts` too. Re-running the Linux HQ bootstrap preserves existing Pi secrets.

Check the live setup:

```bash
kubectl --context k3d-hq -n argocd get applications
kubectl --context k3d-hq -n default get deploy,scaledobject,hpa
curl -fsS http://factory-pi.local:8000/state
```

Open each UI in a separate terminal:

```bash
./expose/grafana_linux.sh  # http://localhost:3000; admin / prom-operator
./expose/argocd_linux.sh   # http://localhost:8080; prints the admin password
```

The solar meter supplies measured panel power. On the current Pi, Kepler uses
model estimates because hardware power counters are unavailable; interpret its
energy and power panels as estimates.

## During the talk

* `kubectl --kubeconfig=./factory.kubeconfig get nodes` — show factory.
* `kubectl --context=k3d-hq get applications -n argocd` — show HQ apps.
* Open the cloudflared URL → Grafana → "Kubernetes / Compute Resources / Cluster"
  dashboard with the `cluster` label set to `factory` to show cross-cluster scrape.
* Open the Kepler dashboard to show power per pod on HQ.

### Solar power mode (real meter)

Pi API now reads real power from FNIRSI FNB48P and derives state automatically:
- `sun` when measured power is `> 0.2 W`
- `cloud` when measured power is `<= 0.2 W`
- if meter reading fails/stales, fallback is `cloud`

Deploy/update the Pi API service:

```bash
./pi/deploy_fnb48p_api.sh
```

This also prepares a freshly flashed Pi: it installs Python/USB dependencies,
creates `/opt/kcd-tuya/.venv`, and creates and enables `kcd-tuya.service` if it
does not already exist. Override the SSH address with
`PI_HOST=192.168.100.18 ./pi/deploy_fnb48p_api.sh` when needed.

Configure the fan and LED on the Pi in `/opt/kcd-tuya/devices.env` using
`sudoedit`. Set `TUYA_FAN_DEVICE_ID`, `TUYA_FAN_IP`, `TUYA_FAN_LOCAL_KEY` and the
corresponding `TUYA_LED_*` values, plus protocol version and switch DP when they
differ from the device defaults. Then run `sudo systemctl restart kcd-tuya`.
Deployments preserve this file and existing systemd service definitions. Without
Tuya credentials, the API can still export USB meter readings, but device control
is unavailable.

To retrieve local keys with an existing Tuya developer project, run on the laptop:

```bash
ssh -t ubuntu@factory-pi.local \
  "sudo sh -c 'umask 077; cd /opt/kcd-tuya; .venv/bin/python -m tinytuya wizard'"
```

Enter the project's Access ID, Access Secret, and region directly in the wizard.
Its private device records are saved on the Pi. Protocol versions and switch DP
numbers must match the actual devices. If Tuya returns `28841002`, its IoT Core
subscription has expired; request **Extend Trial Period** for the existing
subscription and retry after approval. See the
[TinyTuya setup guide](https://github.com/jasonacox/tinytuya#setup-wizard---getting-local-keys).
Once local keys are configured, this API controls the devices directly over LAN.
Keep a private backup of `devices.env` and the wizard's `devices.json` before
reflashing the SD card.

The current private laptop backup is in `.local/tuya/` inside this project. It
contains `devices.env`, `devices.json`, `tinytuya.json`, and `snapshot.json` with
owner-only permissions. This directory is excluded from Git because it contains
local device keys and cloud credentials.

After preparing a replacement SD card and deploying the API, restore the service
configuration from the laptop without printing its contents:

```bash
ssh ubuntu@factory-pi.local 'sudo -n tee /opt/kcd-tuya/devices.env >/dev/null' \
  < .local/tuya/devices.env
ssh ubuntu@factory-pi.local \
  'sudo chmod 600 /opt/kcd-tuya/devices.env && sudo systemctl restart kcd-tuya'
```

Update the device IP addresses first if the LAN has changed.

```bash
# informational current auto-derived state
./pi/solar-sim.sh sun
./pi/solar-sim.sh cloud
./pi/solar-sim.sh state

# manual override states (API-controlled)
./pi/solar-sim.sh blackout   # force both fan and LED off
./pi/solar-sim.sh recover    # exit blackout and return to auto mode
```

On HQ this drives two controller pods in `default` namespace:

* `smart-vetrak-controller` (fan) — KEDA/HPA scales `1` in `sun/cloud`, `0` in `blackout`
* `smart-led-controller` (LED strip) — KEDA/HPA scales `0..1` from `solar_generation_watts`

Grafana dashboard for this loop is provisioned from:

* `hq/manifests/grafana-solar-demo-dashboard.yaml`
* Dashboard title: **Solar Control Loop Demo**
* `hq/manifests/grafana-kepler-power-dashboard.yaml`
* Dashboard title: **Kepler Power Monitor**

## Files

```
factory/
  lima-k0s.yaml              Lima template (Ubuntu + k0s + cloud-init)
  up.sh / down.sh            Create / destroy the VM
  manifests/
    hq-controller-sa.yaml    ServiceAccount + cluster-admin binding for HQ
    exporters.yaml           node-exporter + kube-state-metrics on factory
hq/
  up.sh / down.sh            Start / stop k3d cluster
  bootstrap-argocd.sh        argocd-autopilot bootstrap + push apps + register factory
  gitops/                    Files copied into the GitOps repo
    apps/
      kube-prometheus-stack/
      kepler/
pi/
  deploy_fnb48p_api.sh       Deploy real-power FNB48P API to Raspberry Pi
  solar-sim.sh               Helper for state/blackout/recover API calls
expose/
  cloudflared.sh             Quick tunnel to Grafana
slides/
  package.json               Slidev deps + scripts (dev / build / export)
  slides.md                  The 12-slide deck (1 intro + 10 + 1 outro)
  style.css                  CNCF-blue overrides on top of @slidev/theme-default
  components/                Custom Vue components used in the deck
    CO2Bar.vue               Horizontal bar chart for the transport-CO2 slide
    KeplerLive.vue           Iframe wrapper around the live Grafana Kepler dashboard
  public/                    Static assets — drop logos + backup screenshot here
docs/
  demo-runbook.md            Operator checklist for live demo and recovery steps
```

## Slides

The talk's slide deck lives in `slides/` and is built with [Slidev](https://sli.dev).

### Develop / preview

```bash
cd slides
npm install        # one-time; pulls @slidev/cli, default theme, qrcode addon
npm run dev        # opens http://localhost:3030 with hot-reload
```

Press `p` for presenter mode (speaker notes on a second monitor), `o` for overview,
`d` to draw on the slide.

### Build a static bundle

```bash
cd slides
npm run build      # outputs slides/dist/, deployable on any static host
```

### Export to PDF (offline fallback for the conference)

```bash
cd slides
npm run export     # produces slides-export.pdf
# or
npm run export:pdf # produces feel-the-breeze.pdf
```

PDF export needs Playwright Chromium under the hood — Slidev installs it on first run.

### Editing the deck

* All 12 slides live in a single file: `slides/slides.md` (one slide per `---`-separated block).
* The chart on slide 2 (CO₂ per transport mode) is data-driven via `CO2Bar.vue` —
  edit the `:rows="[...]"` array in the slide to change values.
* The live Grafana iframe on slide 8 takes a `url` prop in `KeplerLive.vue` — set it
  to the cloudflared URL emitted by `./expose/cloudflared.sh` before going on stage,
  and drop a backup PNG at `slides/public/kepler-screenshot.png`.
* QR code on slide 11 is rendered at build time by `slidev-addon-qrcode` — just
  edit the `value="..."` prop in `slides.md` to change the target URL.
* Brand colors come from `slides/style.css` (`--kcd-blue: #0086FF`).

### Pre-talk checklist

0. **Disable corporate VPN/firewall** before the demo — the TLS-intercepting proxy
   blocks ArgoCD's Helm chart fetches. Re-enable after the talk.

1. Drop logos into `slides/public/` (see `slides/public/.placeholder` for the list).
2. Update the GitHub repo URL in slide 11's `<QRCode value="...">` and the outro slide.
3. Bring the cloudflared Grafana URL up before the demo and paste it into
   `<KeplerLive url="...">` on slide 8.
4. `npm run export:pdf` and stash `feel-the-breeze.pdf` on a USB stick — projector
   surprises happen.
