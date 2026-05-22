#!/usr/bin/env bash
# Flash Ubuntu 24.04 Server ARM64 + k0s cloud-init config onto a Raspberry Pi drive (Linux).
# Usage: ./pi/flash_linux.sh /dev/sdX
set -euo pipefail

DISK="${1:-}"
IMAGE_URL="https://cdimage.ubuntu.com/releases/noble/release/ubuntu-24.04.4-preinstalled-server-arm64+raspi.img.xz"
IMAGE_XZ="$(basename "$IMAGE_URL")"
IMAGE="${IMAGE_XZ%.xz}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for cmd in lsblk dd xz mount umount mountpoint mktemp sync; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: missing required command: $cmd" >&2
    exit 1
  fi
done

if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  echo "ERROR: install curl or wget to download the Ubuntu image." >&2
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: run as root: sudo $0 $*" >&2
  exit 1
fi

if [ -z "$DISK" ]; then
  echo "Usage: $0 /dev/sdX" >&2
  echo "Run 'lsblk' to find your flash drive." >&2
  exit 1
fi

if [ ! -b "$DISK" ]; then
  echo "ERROR: $DISK is not a block device." >&2
  exit 1
fi

DISK_TYPE="$(lsblk -dn -o TYPE "$DISK" 2>/dev/null || true)"
if [ "$DISK_TYPE" != "disk" ]; then
  echo "ERROR: $DISK is not a whole-disk device (did you pass a partition?)." >&2
  exit 1
fi

echo "==> Target disk: $DISK"
lsblk -d -o NAME,SIZE,MODEL,TRAN "$DISK"
echo
read -r -p "This will ERASE $DISK. Type YES to continue: " CONFIRM
[ "$CONFIRM" = "YES" ] || { echo "Aborted."; exit 1; }

# Download image if not present
if [ ! -f "$IMAGE" ]; then
  if [ ! -f "$IMAGE_XZ" ]; then
    echo "==> Downloading Ubuntu 24.04 RPi image..."
    if command -v curl >/dev/null 2>&1; then
      curl -L -o "$IMAGE_XZ" "$IMAGE_URL"
    else
      wget -O "$IMAGE_XZ" "$IMAGE_URL"
    fi
  fi
  echo "==> Decompressing..."
  xz -dk "$IMAGE_XZ"
fi

echo "==> Unmounting partitions on $DISK"
while IFS= read -r part; do
  [ -n "$part" ] || continue
  umount "$part" 2>/dev/null || true
done < <(lsblk -lnpo NAME,TYPE "$DISK" | awk '$2=="part"{print $1}')

echo "==> Flashing image (this takes a few minutes)..."
dd if="$IMAGE" of="$DISK" bs=4M conv=fsync status=progress
sync

if command -v partprobe >/dev/null 2>&1; then
  partprobe "$DISK" || true
fi
sleep 3

BOOT_PART=""
if command -v blkid >/dev/null 2>&1; then
  while IFS= read -r part; do
    [ -n "$part" ] || continue
    if [ "$(blkid -s LABEL -o value "$part" 2>/dev/null || true)" = "system-boot" ]; then
      BOOT_PART="$part"
      break
    fi
  done < <(lsblk -lnpo NAME,TYPE "$DISK" | awk '$2=="part"{print $1}')
fi
if [ -z "$BOOT_PART" ]; then
  BOOT_PART="$(lsblk -lnpo NAME,TYPE,FSTYPE "$DISK" | awk '$2=="part" && $3=="vfat"{print $1; exit}')"
fi
if [ -z "$BOOT_PART" ]; then
  echo "ERROR: could not find the boot partition (label 'system-boot')." >&2
  exit 1
fi

MOUNT_DIR="$(mktemp -d /tmp/system-boot.XXXXXX)"
cleanup() {
  if mountpoint -q "$MOUNT_DIR"; then
    umount "$MOUNT_DIR" || true
  fi
  rmdir "$MOUNT_DIR" 2>/dev/null || true
}
trap cleanup EXIT

echo "==> Mounting boot partition: $BOOT_PART"
mount "$BOOT_PART" "$MOUNT_DIR"

echo "==> Writing cloud-init config..."
cp "$SCRIPT_DIR/user-data"      "$MOUNT_DIR/user-data"
cp "$SCRIPT_DIR/network-config" "$MOUNT_DIR/network-config"
sync

umount "$MOUNT_DIR"
trap - EXIT
rmdir "$MOUNT_DIR"

echo
echo "Done. Insert the drive into the Raspberry Pi and power on."
echo "k0s will install itself on first boot (~5 min)."
echo
echo "Once up, reach it from any device on the same network:"
echo "  ping factory-pi.local"
echo "  ssh ubuntu@factory-pi.local"
echo "  kubectl --kubeconfig=<(ssh ubuntu@factory-pi.local cat .kube/config) get nodes"
