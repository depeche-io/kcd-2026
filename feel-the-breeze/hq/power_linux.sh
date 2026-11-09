#!/usr/bin/env bash
# Preserve the existing laptop HQ cluster. No cluster/container/data deletion.
set -euo pipefail
ACTION="${1:-}"
case "$ACTION" in start|stop) ;; *) echo 'Usage: power_linux.sh start|stop' >&2; exit 2;; esac
SCRIPT="$(readlink -f "$0")"
DOCKER=(/usr/bin/docker --host unix:///var/run/docker.sock)
if ! timeout 10 "${DOCKER[@]}" info >/dev/null 2>&1; then
  if [ "$(id -u)" != 0 ]; then
    if [ -t 0 ]; then
      echo 'Authenticate with sudo in this terminal to manage the existing HQ containers.'
      exec sudo /usr/bin/bash "$SCRIPT" "$ACTION"
    fi
    echo 'System authentication is needed to manage the existing HQ containers.'
    exec pkexec /usr/bin/bash "$SCRIPT" "$ACTION"
  fi
  echo 'ERROR: the original Docker daemon is unavailable; start Docker first.' >&2
  exit 1
fi

# Pin the existing cluster and socket; never fall back to another runtime.
for name in k3d-hq-serverlb k3d-hq-server-0 k3d-hq-agent-0; do
  labels="$("${DOCKER[@]}" inspect --format '{{index .Config.Labels "app"}}/{{index .Config.Labels "k3d.cluster"}}' "$name")"
  [ "$labels" = k3d/hq ] || { echo "ERROR: unexpected ownership of $name" >&2; exit 1; }
done

if [ "$ACTION" = start ]; then
  # Use the same laptop kubeconfig that demo_linux.py uses. When this helper
  # runs under sudo/pkexec, perform the read-only readiness query as its owner.
  LAPTOP_UID="$(stat -c %u "$(dirname "$SCRIPT")/..")"
  LAPTOP_USER="$(getent passwd "$LAPTOP_UID" | cut -d: -f1)"
  LAPTOP_HOME="$(getent passwd "$LAPTOP_UID" | cut -d: -f6)"
  KUBECTL_BIN="$(command -v kubectl || true)"
  [ -n "$KUBECTL_BIN" ] || KUBECTL_BIN=/snap/bin/kubectl
  if [ -z "$LAPTOP_USER" ] || [ ! -s "$LAPTOP_HOME/.kube/config" ] || [ ! -x "$KUBECTL_BIN" ]; then
    echo 'ERROR: existing laptop kubeconfig or kubectl is unavailable.' >&2
    exit 1
  fi
  HOST_KUBECTL=("$KUBECTL_BIN" --kubeconfig "$LAPTOP_HOME/.kube/config" --context k3d-hq --request-timeout=10s)
  if [ "$(id -u)" = 0 ]; then
    HOST_KUBECTL=(/usr/sbin/runuser -u "$LAPTOP_USER" -- "${HOST_KUBECTL[@]}")
  fi
  "${DOCKER[@]}" start k3d-hq-serverlb k3d-hq-server-0
  # Let the server finish starting before the agent's entrypoint runs.
  echo 'Waiting for HQ server through the existing laptop context...'
  CHECK_DEADLINE=$((SECONDS + 210))
  CHECK_REPORTED=0
  until CHECK_OUTPUT="$("${HOST_KUBECTL[@]}" wait node/k3d-hq-server-0 --for=condition=Ready --timeout=10s 2>&1)"; do
    if [ "$CHECK_REPORTED" = 0 ] || [ "$SECONDS" -ge "$CHECK_DEADLINE" ]; then
      printf '%s\n' "$CHECK_OUTPUT" >&2
      CHECK_REPORTED=1
    fi
    if [ "$SECONDS" -ge "$CHECK_DEADLINE" ]; then
      echo 'ERROR: HQ server did not become ready; worker has not been restarted.' >&2
      exit 1
    fi
    sleep 3
  done
  printf '%s\n' "$CHECK_OUTPUT"
  if [ "$("${DOCKER[@]}" inspect --format '{{.State.Running}}' k3d-hq-agent-0)" = true ]; then
    "${DOCKER[@]}" restart --timeout 60 k3d-hq-agent-0
  else
    "${DOCKER[@]}" start k3d-hq-agent-0
  fi
else
  # Stop the worker cleanly while its Kubernetes server is still available.
  "${DOCKER[@]}" stop --timeout 60 k3d-hq-agent-0
  "${DOCKER[@]}" stop --timeout 60 k3d-hq-server-0
  "${DOCKER[@]}" stop --timeout 20 k3d-hq-serverlb
  for name in k3d-hq-agent-0 k3d-hq-server-0 k3d-hq-serverlb; do
    [ "$("${DOCKER[@]}" inspect --format '{{.State.Running}}' "$name")" = false ] || exit 1
  done
fi
echo "HQ containers: $ACTION completed; stored cluster data retained."
