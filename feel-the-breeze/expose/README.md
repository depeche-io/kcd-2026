# Exposing the demo

For a live talk you have a few good options. They all share the same idea:
run a `kubectl port-forward` to Grafana (or ArgoCD), then tunnel that local
port to the public internet.

## 1. Cloudflare quick tunnel (default — easiest)

```bash
brew install cloudflared
./expose/cloudflared.sh
```

* No account, no DNS, no signup.
* Burns a fresh `*.trycloudflare.com` URL each run — fine for a single talk.
* No banner page, no rate limit visible to the audience.

## 2. Cloudflare named tunnel (most reliable)

If you want the same URL across rehearsals and the actual talk:

```bash
cloudflared tunnel login                              # opens browser
cloudflared tunnel create kcd-demo
cloudflared tunnel route dns kcd-demo demo.example.com
cloudflared tunnel run --url http://localhost:3000 kcd-demo
```

Requires a domain on Cloudflare. Tunnel URL persists; only the port-forward
needs to be running.

## 3. ngrok (fallback)

```bash
brew install ngrok
ngrok config add-authtoken <token>
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80 &
ngrok http 3000
```

Caveats for a live talk: free tier shows a one-time browser warning page
the first time each viewer connects, and free tunnels rotate URL on every
restart. A reserved subdomain costs money.

## 4. Tailscale Funnel

```bash
tailscale up
tailscale serve http://localhost:3000
tailscale funnel 3000 on
```

Requires Tailscale on the laptop and the user's tailnet. Public HTTPS at
`https://<machine>.<tailnet>.ts.net`. Very reliable, no time limits.

## What to expose

* **Grafana** is the natural target — dashboards travel well on a projector,
  and anonymous Viewer access is enabled in the Helm values so the audience
  doesn't need a login.
* **ArgoCD UI** can also be tunneled (port `8080` against `svc/argocd-server`)
  if you want to show sync status live, but the UI is busier on a projector.
