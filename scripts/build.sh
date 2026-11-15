#!/usr/bin/env bash
# ==============================================================================
# F77 OS - Live Bootable ISO Builder
# Target: Ubuntu 24.04 LTS (Noble Numbat) base
# Output: f77-os-v1.0-amd64.iso (Hybrid BIOS + UEFI)
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
# Install packages defined in packages.list
grep -v '^#' /tmp/packages.list | grep -v '^$' | xargs apt-get install -y --no-install-recommends

# Run desktop setup
/tmp/setup-desktop.sh
rm -f /tmp/packages.list /tmp/setup-desktop.sh

# Setup Live User
useradd -m -s /bin/bash -G sudo,adm,dialout,cdrom,audio,dip,video,plugdev f77
echo "f77:f77" | chpasswd
echo "f77 ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/f77
chmod 0440 /etc/sudoers.d/f77

# Clean apt cache
apt-get autoremove -y
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

echo "[6/7] Setting Up GRUB Bootloader (UEFI + BIOS)..."
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

echo "[7/7] Generating Hybrid Bootable ISO Image with Xorriso..."
xorriso -as mkisofs \
    -r -V "F77_OS_LIVE" \
    -o "${ISO_NAME}" \
    -J -l \
    -b boot/grub/grub.cfg \
    -c boot.catalog \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    "${IMAGE_DIR}"

sha256sum "${ISO_NAME}" > "${ISO_NAME}.sha256"

echo "============================================================"
echo "          F77 OS BUILD COMPLETED SUCCESSFULLY!              "
echo "  Output: ${ISO_NAME}                                       "
echo "  Checksum: $(cat "${ISO_NAME}.sha256")                     "
echo "============================================================"
