#!/usr/bin/env bash
# Flash Ubuntu 24.04 Server ARM64 + k0s cloud-init config onto a Raspberry Pi drive.
# Usage: ./pi/flash.sh /dev/diskN
set -euo pipefail

DISK="${1:-}"
IMAGE_URL="https://cdimage.ubuntu.com/releases/noble/release/ubuntu-24.04.4-preinstalled-server-arm64+raspi.img.xz"
IMAGE_XZ="$(basename "$IMAGE_URL")"
IMAGE="${IMAGE_XZ%.xz}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: run as root: sudo $0 $*" >&2
  exit 1
fi

if [ -z "$DISK" ]; then
  echo "Usage: $0 /dev/diskN" >&2
  echo "Run 'diskutil list' to find your flash drive." >&2
  exit 1
fi

if [ ! -b "$DISK" ]; then
  echo "ERROR: $DISK is not a block device." >&2
  exit 1
fi

echo "==> Target disk: $DISK"
diskutil info "$DISK" | grep -E "Device|Size|Media Name"
echo
read -r -p "This will ERASE $DISK. Type YES to continue: " CONFIRM
[ "$CONFIRM" = "YES" ] || { echo "Aborted."; exit 1; }

# Download image if not present
if [ ! -f "$IMAGE" ]; then
  if [ ! -f "$IMAGE_XZ" ]; then
    echo "==> Downloading Ubuntu 24.04 RPi image..."
    curl -L -o "$IMAGE_XZ" "$IMAGE_URL"
  fi
  echo "==> Decompressing..."
  xz -dk "$IMAGE_XZ"
fi

echo "==> Unmounting $DISK"
diskutil unmountDisk force "$DISK"

echo "==> Flashing image (this takes a few minutes)..."
RDISK="${DISK/disk/rdisk}"
if ! dd if="$IMAGE" of="$RDISK" bs=4m 2>/dev/null; then
  echo
  echo "ERROR: cannot write to $RDISK." >&2
  echo >&2
  echo "  1. Check the physical write-protect switch on the SD card adapter — slide it up (unlocked)." >&2
  echo "  2. If still failing: System Settings → Privacy & Security → Full Disk Access → add Terminal." >&2
  exit 1
fi
sync

echo "==> Remounting partitions..."
diskutil mountDisk "$DISK"
sleep 3

BOOT_VOL="/Volumes/system-boot"
if [ ! -d "$BOOT_VOL" ]; then
  echo "ERROR: $BOOT_VOL not found after flash. Check diskutil list." >&2
  exit 1
fi

echo "==> Writing cloud-init config..."
cp "$SCRIPT_DIR/user-data"      "$BOOT_VOL/user-data"
cp "$SCRIPT_DIR/network-config" "$BOOT_VOL/network-config"

echo "==> Ejecting $DISK"
diskutil eject "$DISK"

echo
echo "Done. Insert the drive into the Raspberry Pi and power on."
echo "k0s will install itself on first boot (~5 min)."
echo
echo "Once up, reach it from any device on the same network:"
echo "  ping factory-pi.local"
echo "  ssh ubuntu@factory-pi.local"
echo "  kubectl --kubeconfig=<(ssh ubuntu@factory-pi.local cat .kube/config) get nodes"
