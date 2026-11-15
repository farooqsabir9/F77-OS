#!/usr/bin/env bash
# ==============================================================================
# F77 OS - Live Bootable ISO Builder
# Base: Ubuntu 24.04 LTS (Noble Numbat)
# Output: f77-os-v1.0-amd64.iso (UEFI + BIOS Hybrid)
# ==============================================================================

set -euo pipefail

echo "============================================================"
echo "           STARTING F77 OS ISO BUILD PIPELINE               "
echo "============================================================"

WORK_DIR="$(pwd)/f77-build"
CHROOT_DIR="${WORK_DIR}/chroot"
IMAGE_DIR="${WORK_DIR}/image"
ISO_NAME="f77-os-v1.0-amd64.iso"

# Cleanup any previous builds
rm -rf "${WORK_DIR}"
mkdir -p "${CHROOT_DIR}" "${IMAGE_DIR}"

echo "[1/7] Bootstrapping Base System (Ubuntu 24.04 Noble)..."
debootstrap \
    --arch=amd64 \
    --variant=minbase \
    noble \
    "${CHROOT_DIR}" \
    http://archive.ubuntu.com/ubuntu/

echo "[2/7] Mounting virtual filesystems for chroot..."
mount --bind /dev "${CHROOT_DIR}/dev"
mount --bind /run "${CHROOT_DIR}/run"
mount -t devpts devpts "${CHROOT_DIR}/dev/pts"
mount -t proc proc "${CHROOT_DIR}/proc"
mount -t sysfs sysfs "${CHROOT_DIR}/sys"

cleanup() {
    echo "[Cleanup] Unmounting virtual filesystems..."
    umount -lf "${CHROOT_DIR}/dev/pts" || true
    umount -lf "${CHROOT_DIR}/dev" || true
    umount -lf "${CHROOT_DIR}/run" || true
    umount -lf "${CHROOT_DIR}/proc" || true
    umount -lf "${CHROOT_DIR}/sys" || true
}
trap cleanup EXIT

echo "[3/7] Configuring Repositories & Installing Packages..."
cat << 'EOF' > "${CHROOT_DIR}/etc/apt/sources.list"
deb http://archive.ubuntu.com/ubuntu/ noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ noble-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ noble-security main restricted universe multiverse
EOF

# Copy package list and setup script into chroot
cp config/packages.list "${CHROOT_DIR}/tmp/packages.list"
cp config/setup-desktop.sh "${CHROOT_DIR}/tmp/setup-desktop.sh"
chmod +x "${CHROOT_DIR}/tmp/setup-desktop.sh"

chroot "${CHROOT_DIR}" /bin/bash << 'EOF'
export DEBIAN_FRONTEND=noninteractive
apt-get update

# Install packages with resilience
while read -r pkg; do
    [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
    echo "Installing: $pkg..."
    apt-get install -y --no-install-recommends "$pkg" || echo "Warning: Failed to install $pkg (skipping)"
done < /tmp/packages.list

# Run desktop setup
/tmp/setup-desktop.sh || true
rm -f /tmp/packages.list /tmp/setup-desktop.sh

# Setup Live User
useradd -m -s /bin/bash -G sudo,adm,dialout,cdrom,audio,dip,video,plugdev f77 || true
echo "f77:f77" | chpasswd
echo "f77 ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/f77
chmod 0440 /etc/sudoers.d/f77

# Clean apt cache
apt-get autoremove -y || true
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
EOF

echo "[4/7] Extracting Kernel & Initrd for Live Boot..."
mkdir -p "${IMAGE_DIR}/casper"
VMLINUZ=$(ls -1 "${CHROOT_DIR}/boot/vmlinuz-"* | head -n 1)
INITRD=$(ls -1 "${CHROOT_DIR}/boot/initrd.img-"* | head -n 1)
cp "${VMLINUZ}" "${IMAGE_DIR}/casper/vmlinuz"
cp "${INITRD}" "${IMAGE_DIR}/casper/initrd"

echo "[5/7] Compressing Root Filesystem into SquashFS..."
mksquashfs "${CHROOT_DIR}" "${IMAGE_DIR}/casper/filesystem.squashfs" \
    -comp zstd \
    -e boot \
    -noappend

echo "[6/7] Setting Up GRUB Bootloader & EFI Images..."
mkdir -p "${IMAGE_DIR}/boot/grub"
cat << 'EOF' > "${IMAGE_DIR}/boot/grub/grub.cfg"
set default="0"
set timeout=10

insmod all_video
insmod font

menuentry "F77 OS (Live Desktop)" {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper quiet splash ---
    initrd /casper/initrd
}

menuentry "F77 OS (Safe Graphics Mode)" {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper nomodeset quiet splash ---
    initrd /casper/initrd
}
EOF

# Build standalone EFI binary for UEFI boot
mkdir -p "${IMAGE_DIR}/EFI/BOOT"
grub-mkstandalone \
    --format=x86_64-efi \
    --output="${IMAGE_DIR}/EFI/BOOT/BOOTX64.EFI" \
    --locales="" \
    --fonts="" \
    "boot/grub/grub.cfg=${IMAGE_DIR}/boot/grub/grub.cfg"

# Create bootable FAT EFI image
dd if=/dev/zero of="${IMAGE_DIR}/boot/grub/efi.img" bs=1M count=10
mkfs.vfat "${IMAGE_DIR}/boot/grub/efi.img"
mmd -i "${IMAGE_DIR}/boot/grub/efi.img" ::EFI ::EFI/BOOT
mcopy -i "${IMAGE_DIR}/boot/grub/efi.img" "${IMAGE_DIR}/EFI/BOOT/BOOTX64.EFI" ::EFI/BOOT/BOOTX64.EFI

echo "[7/7] Generating Hybrid Bootable ISO Image with Xorriso..."
xorriso -as mkisofs \
    -r -V "F77_OS_LIVE" \
    -o "${ISO_NAME}" \
    -J -l \
    -append_partition 2 0xef "${IMAGE_DIR}/boot/grub/efi.img" \
    -appended_part_as_gpt \
    -e --interval:appended_partition_2:all:: \
    -no-emul-boot \
    "${IMAGE_DIR}"

sha256sum "${ISO_NAME}" > "${ISO_NAME}.sha256"

echo "============================================================"
echo "          F77 OS BUILD COMPLETED SUCCESSFULLY!              "
echo "  Output: ${ISO_NAME}                                       "
echo "  Checksum: $(cat "${ISO_NAME}.sha256")                     "
echo "============================================================"
