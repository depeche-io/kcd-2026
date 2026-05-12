#!/usr/bin/env bash
# Copy cloud-init config onto an already-flashed Ubuntu RPi drive.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BOOT_VOL="/Volumes/system-boot"

if [ ! -d "$BOOT_VOL" ]; then
  echo "ERROR: $BOOT_VOL not found. Insert the drive and ensure it is mounted." >&2
  exit 1
fi

cp "$SCRIPT_DIR/user-data"      "$BOOT_VOL/user-data"
cp "$SCRIPT_DIR/network-config" "$BOOT_VOL/network-config"
diskutil eject "$(diskutil info "$BOOT_VOL" | awk '/Part of Whole:/{print "/dev/"$NF}')"

echo "Done. Boot the Pi — k0s installs on first boot (~5 min)."
echo "Then: ssh ubuntu@factory-pi.local"
