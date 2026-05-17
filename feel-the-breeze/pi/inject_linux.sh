#!/usr/bin/env bash
# Copy cloud-init config onto an already-flashed Ubuntu RPi drive (Linux).
# Usage: ./pi/inject_linux.sh [/dev/sdX1]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BOOT_PART="${1:-}"

for cmd in cp mount umount findmnt lsblk mktemp mountpoint sync; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: missing required command: $cmd" >&2
    exit 1
  fi
done

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: run as root: sudo $0 $*" >&2
  exit 1
fi

if [ -z "$BOOT_PART" ]; then
  if command -v blkid >/dev/null 2>&1; then
    while IFS= read -r part; do
      [ -n "$part" ] || continue
      if [ "$(blkid -s LABEL -o value "$part" 2>/dev/null || true)" = "system-boot" ]; then
        BOOT_PART="$part"
        break
      fi
    done < <(lsblk -lnpo NAME,TYPE | awk '$2=="part"{print $1}')
  fi
fi

if [ -z "$BOOT_PART" ]; then
  echo "ERROR: boot partition not found. Pass it explicitly, e.g. $0 /dev/sdX1" >&2
  exit 1
fi

if [ ! -b "$BOOT_PART" ]; then
  echo "ERROR: $BOOT_PART is not a block device." >&2
  exit 1
fi

MOUNTED_HERE="$(findmnt -n -o TARGET --source "$BOOT_PART" 2>/dev/null || true)"
TEMP_MOUNT=""

cleanup() {
  if [ -n "$TEMP_MOUNT" ] && mountpoint -q "$TEMP_MOUNT"; then
    umount "$TEMP_MOUNT" || true
  fi
  if [ -n "$TEMP_MOUNT" ]; then
    rmdir "$TEMP_MOUNT" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if [ -n "$MOUNTED_HERE" ]; then
  BOOT_VOL="$MOUNTED_HERE"
else
  TEMP_MOUNT="$(mktemp -d /tmp/system-boot.XXXXXX)"
  mount "$BOOT_PART" "$TEMP_MOUNT"
  BOOT_VOL="$TEMP_MOUNT"
fi

echo "==> Writing cloud-init config to $BOOT_VOL"
cp "$SCRIPT_DIR/user-data"      "$BOOT_VOL/user-data"
cp "$SCRIPT_DIR/network-config" "$BOOT_VOL/network-config"
sync

if [ -n "$TEMP_MOUNT" ]; then
  umount "$TEMP_MOUNT"
  rmdir "$TEMP_MOUNT"
  trap - EXIT
fi

echo "Done. Boot the Pi — k0s installs on first boot (~5 min)."
echo "Then: ssh ubuntu@factory-pi.local"
