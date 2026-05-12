#!/usr/bin/env bash
set -euo pipefail
VM_NAME="${FACTORY_VM_NAME:-factory}"

if limactl list -q | grep -qx "$VM_NAME"; then
  limactl stop "$VM_NAME" || true
  limactl delete "$VM_NAME"
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
rm -f "$ROOT/factory.kubeconfig" "$ROOT/factory.kubeconfig.host"
echo "factory deleted."
