#!/usr/bin/env bash
# Flash Ubuntu 24.04 Server ARM64 + k0s cloud-init config onto a Raspberry Pi drive (Linux).
# Usage: ./pi/flash_linux.sh /dev/sdX
# Offline preparation without writing a disk: ./pi/flash_linux.sh --prepare-only
set -euo pipefail

DISK="${1:-}"
IMAGE_URL="https://cdimage.ubuntu.com/releases/noble/release/ubuntu-24.04.4-preinstalled-server-arm64+raspi.img.xz"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SEED_DIR="$SCRIPT_DIR/../.local/pi/seed"
IMAGE_XZ="$SCRIPT_DIR/$(basename "$IMAGE_URL")"
IMAGE="${IMAGE_XZ%.xz}"
IMAGE_SHA256="790652faeb4f61ce7bb12f5cb61734595c61d3cd882915b8b5f9918106c80d37"

if [ "$DISK" = --prepare-only ]; then
  exec python3 "$SCRIPT_DIR/prepare_autoflash.py" --output "$SEED_DIR"
fi

for cmd in lsblk dd xz mount umount mountpoint mktemp sync cp cmp awk findmnt readlink blockdev stat sha256sum grep python3 ssh-keygen; do
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
DISK="$(readlink -f "$DISK")"

DISK_TYPE="$(lsblk -dn -o TYPE "$DISK" 2>/dev/null || true)"
if [ "$DISK_TYPE" != "disk" ]; then
  echo "ERROR: $DISK is not a whole-disk device (did you pass a partition?)." >&2
  exit 1
fi

# Refuse disks backing the running system, including LVM/encrypted devices.
for system_path in / /boot /boot/efi /usr /var /home "$SCRIPT_DIR"; do
  [ -e "$system_path" ] || continue
  source_device="$(findmnt -n -o SOURCE --target "$system_path")"
  source_device="${source_device%%\[*}"
  if [ -b "$source_device" ] && lsblk -snrpo NAME "$source_device" | grep -Fxq "$DISK"; then
    echo "ERROR: $DISK contains the running system or source files ($system_path)." >&2
    exit 1
  fi
done
if lsblk -nrpo MOUNTPOINTS "$DISK" | grep -Fxq '[SWAP]'; then
  echo "ERROR: $DISK contains active swap." >&2
  exit 1
fi
if [ "$(blockdev --getro "$DISK")" != "0" ]; then
  echo "ERROR: $DISK is read-only. Check the SD adapter's write-protect switch." >&2
  exit 1
fi
for config in user-data network-config; do
  if [ ! -s "$SCRIPT_DIR/$config" ]; then
    echo "ERROR: missing or empty config: $SCRIPT_DIR/$config" >&2
    exit 1
  fi
done
if [ ! -f "$SCRIPT_DIR/../.local/pi/automation-installed.json" ]; then
  echo "ERROR: install laptop automation first: python3 $SCRIPT_DIR/install_autoreconnect.py" >&2
  exit 1
fi
echo "==> Preparing private restore seed..."
python3 "$SCRIPT_DIR/prepare_autoflash.py" --output "$SEED_DIR"

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
      curl -fL -o "$IMAGE_XZ.part" "$IMAGE_URL"
    else
      wget -O "$IMAGE_XZ.part" "$IMAGE_URL"
    fi
    mv "$IMAGE_XZ.part" "$IMAGE_XZ"
  fi
fi
if [ -f "$IMAGE_XZ" ]; then
  echo "==> Verifying Ubuntu image checksum..."
  printf '%s  %s\n' "$IMAGE_SHA256" "$IMAGE_XZ" | sha256sum -c -
fi
if [ ! -f "$IMAGE" ]; then
  echo "==> Decompressing..."
  xz -dk "$IMAGE_XZ"
fi
if [ -f "$IMAGE_XZ" ]; then
  echo "==> Checking decompressed image..."
  xz -dc "$IMAGE_XZ" | cmp - "$IMAGE"
fi
if [ "$(stat -c %s "$IMAGE")" -gt "$(blockdev --getsize64 "$DISK")" ]; then
  echo "ERROR: image is larger than $DISK." >&2
  exit 1
fi

echo "==> Unmounting partitions on $DISK"
while IFS= read -r part; do
  [ -n "$part" ] || continue
  if findmnt -rn --source "$part" >/dev/null; then
    umount "$part"
  fi
done < <(lsblk -lnpo NAME,TYPE "$DISK" | awk '$2=="part"{print $1}')
if [ -n "$(lsblk -nrpo MOUNTPOINTS "$DISK" | awk 'NF')" ]; then
  echo "ERROR: $DISK still has mounted filesystems; refusing to overwrite it." >&2
  exit 1
fi

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
cp "$SEED_DIR/user-data"      "$MOUNT_DIR/user-data"
cp "$SEED_DIR/network-config" "$MOUNT_DIR/network-config"
cp "$SEED_DIR/meta-data"      "$MOUNT_DIR/meta-data"
sync
cmp "$SEED_DIR/user-data" "$MOUNT_DIR/user-data"
cmp "$SEED_DIR/network-config" "$MOUNT_DIR/network-config"
cmp "$SEED_DIR/meta-data" "$MOUNT_DIR/meta-data"

umount "$MOUNT_DIR"
trap - EXIT
rmdir "$MOUNT_DIR"
python3 "$SCRIPT_DIR/prepare_autoflash.py" --arm "$SEED_DIR/manifest.json"

echo
echo "Done. Insert the drive into the Raspberry Pi and power on."
echo "The Pi will restore k0s, its API and Tuya devices on first boot (internet required)."
echo "The laptop's kcd-pi-reconnect.timer will register it with HQ when ready."
echo
echo "Once up, reach it from any device on the same network:"
echo "  ping factory-pi.local"
echo "  ssh ubuntu@factory-pi.local"
echo "  kubectl --kubeconfig=<(ssh ubuntu@factory-pi.local cat .kube/config) get nodes"
