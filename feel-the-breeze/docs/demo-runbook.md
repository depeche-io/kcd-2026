# Demo Runbook (Feel the Breeze)

This is the quick operator guide for live presentation.

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

Expected:
- `solar_generation_watts > 0.5`
- fan pod ON (`smart-vetrak-controller=1`)
- led pod ON (`smart-led-controller=1`)

### B) Cloud mode (automatic from real power)

Reduce panel input so measured power drops below `0.5 W`.

Expected (after scrape/poll delay):
- `solar_generation_watts <= 0.5`
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
- both controllers back ON (`1/1`)

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

## 5. Safety reset (known-good state)

```bash
./pi/solar-sim.sh recover
kubectl --context k3d-hq -n default get deploy smart-vetrak-controller smart-led-controller
```
