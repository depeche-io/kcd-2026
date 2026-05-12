#!/usr/bin/env bash
set -euo pipefail
CLUSTER="${K3D_CLUSTER:-hq}"
k3d cluster delete "$CLUSTER" || true
echo "hq deleted."
