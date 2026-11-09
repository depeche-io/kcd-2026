# Demo Runbook (Feel the Breeze)

This is the quick operator guide for live presentation.

For travel with the existing installation, run `python3 demo_linux.py stop` and
wait for shutdown before disconnecting power. At the destination, connect all
devices to the LAN and run `python3 demo_linux.py start` from `feel-the-breeze`.
This preserves HQ/SD configuration and restores the UI, device addresses and
KEDA control. A new Wi-Fi SSID must first be configured on Pi and both Tuya
devices; changed Tuya pairing keys require updating the private configuration.
See [travel shutdown/startup](../README.md#stop-for-travel-and-resume-the-existing-demo).

For a fresh Linux + physical Pi installation, follow the
[README startup procedure](../README.md#linux--raspberry-pi) first. This runbook
assumes `kcd-tuya.service` has the real Tuya device IDs, local keys, LAN addresses,
protocol versions, and switch DP numbers configured in `/opt/kcd-tuya/devices.env`.

For the prepared laptop, a later Wi-Fi-only reflash uses
`sudo ./pi/flash_linux.sh /dev/mmcblk0` after editing `pi/network-config`.
Pi bootstrap and the user timer `kcd-pi-reconnect.timer` restore the setup
automatically. First boot needs internet/NTP, and the Tuya devices must be on
the reachable LAN with their original pairing/keys. The new automation still
needs its first full reflash hardware validation.

## 1. Pre-flight (5-10 min before)

Run from repo root:

```bash
cd ~/kcd2026/kcd-2026/feel-the-breeze
```

Check HQ cluster and workloads:

```bash
kubectl --context k3d-hq get nodes
kubectl --context k3d-hq -n default get deploy,scaledobject,hpa
kubectl --context k3d-hq -n monitoring get pods
```

If `k3d-hq-agent-0` remains `NotReady` after restarting the laptop, check the
existing container with `sudo docker logs --tail 100 k3d-hq-agent-0` and restart
it with `sudo docker restart k3d-hq-agent-0`. Then wait for the node, Prometheus
and the ArgoCD application controller to become ready. A running Docker
container or reachable Kubernetes API alone does not confirm HQ recovery.

Check Pi API health:

```bash
curl -fsS http://factory-pi.local:8000/healthz
curl -fsS http://factory-pi.local:8000/state
```

Open Grafana:

```bash
kubectl --context k3d-hq -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Dashboard:
- `Solar Control Loop Demo`
- `Kepler Power Monitor`

## 2. Demo sequence (talk track)

### A) Sun / nominal mode

```bash
./pi/solar-sim.sh recover
```

Illuminate the panel so the real measured power exceeds `0.2 W`.

Expected:
- `solar_generation_watts > 0.2`
- fan pod ON (`smart-vetrak-controller=1`)
- led pod ON (`smart-led-controller=1`)

### B) Cloud mode (automatic from real power)

Reduce panel input so measured power drops below `0.2 W`.

Expected (after scrape/poll delay):
- `solar_generation_watts <= 0.2`
- fan pod stays ON (`smart-vetrak-controller=1`)
- led pod scales OFF (`smart-led-controller=0`)

### C) Blackout mode

```bash
./pi/solar-sim.sh blackout
```

Expected (after scrape/poll delay):
- `solar_generation_watts ~= 0.2`
- fan pod OFF (`smart-vetrak-controller=0`)
- led pod OFF (`smart-led-controller=0`)

### D) Recover back to nominal

```bash
./pi/solar-sim.sh recover
```

Expected:
- fan controller back ON (`1`)
- LED controller follows the real meter (`1` above `0.2 W`, otherwise `0`)

`sun` and `cloud` only report the meter-derived state; they do not simulate power.

## 3. Live verification commands

```bash
kubectl --context k3d-hq -n default get deploy smart-vetrak-controller smart-led-controller
kubectl --context k3d-hq -n default get scaledobject fan-autoscaler led-autoscaler
```

Prometheus quick checks:

```bash
kubectl --context k3d-hq -n monitoring exec prometheus-kube-prometheus-stack-prometheus-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=max(solar_generation_watts%7Bcluster%3D%22factory-pi%22%7D)'

kubectl --context k3d-hq -n monitoring exec prometheus-kube-prometheus-stack-prometheus-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=max(fan_controller_enabled%7Bcluster%3D%22factory-pi%22%7D)'
```

## 4. Troubleshooting

If Grafana shows `No data`:

```bash
kubectl --context k3d-hq -n monitoring get pods
kubectl --context k3d-hq -n monitoring get endpoints kube-prometheus-stack-prometheus
```

If LED/fan does not scale after state change:
- wait 20-40s (Prometheus scrape + KEDA polling)
- check scaler status:

```bash
kubectl --context k3d-hq -n default describe scaledobject led-autoscaler
kubectl --context k3d-hq -n default describe scaledobject fan-autoscaler
```

If Pi API is not reachable:

```bash
curl -v http://factory-pi.local:8000/healthz
ssh ubuntu@factory-pi.local 'sudo systemctl status kcd-tuya.service --no-pager'
```

After an automatic reflash, inspect `journalctl --user -u kcd-pi-reconnect.service`
on the laptop and `sudo journalctl -u kcd-bootstrap.service` on the Pi. The Pi
may still be installing packages or waiting for clock synchronization / Tuya
discovery. See the README for the dedicated SSH identity used during bootstrap.

If `/healthz` succeeds but device control returns HTTP 500, check the response
body and `journalctl -u kcd-tuya.service` on the Pi. An unconfigured Tuya device
does not prevent meter readings, but it cannot be switched until its credentials
are restored. Recreate the service after a fresh flash with
`./pi/deploy_fnb48p_api.sh`.

The Kepler panels on this Pi use model estimates. The solar dashboard displays
measured FNB48P panel power.

## 5. Safety reset (known-good state)

```bash
./pi/solar-sim.sh recover
kubectl --context k3d-hq -n default get deploy smart-vetrak-controller smart-led-controller
```
