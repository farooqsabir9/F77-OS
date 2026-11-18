#!/usr/bin/env bash
# ==============================================================================
# F77 OS - High Performance Live Bootable ISO Builder
# Base: Ubuntu 24.04 LTS (Noble Numbat)
# Output: f77-os-v1.0-amd64.iso (Hybrid BIOS + UEFI Bootable)
# ==============================================================================

set -euo pipefail

echo "============================================================"
echo "           STARTING F77 OS ISO BUILD PIPELINE               "
echo "============================================================"

WORK_DIR="$(pwd)/f77-build"
CHROOT_DIR="${WORK_DIR}/chroot"
IMAGE_DIR="${WORK_DIR}/image"
ISO_NAME="f77-os-v1.0-amd64.iso"
NUM_CORES=$(nproc || echo 4)

echo "Detected CPU Cores: ${NUM_CORES}"

# Cleanup any previous builds
rm -rf "${WORK_DIR}"
mkdir -p "${CHROOT_DIR}" "${IMAGE_DIR}"

echo "[1/6] Bootstrapping Base System (Ubuntu 24.04 Noble)..."
debootstrap \
    --arch=amd64 \
    --variant=minbase \
    noble \
    "${CHROOT_DIR}" \
    http://archive.ubuntu.com/ubuntu/

echo "[2/6] Mounting virtual filesystems for chroot..."
mount --bind /dev "${CHROOT_DIR}/dev"
mount --bind /run "${CHROOT_DIR}/run"
mount -t devpts devpts "${CHROOT_DIR}/dev/pts"
mount -t proc proc "${CHROOT_DIR}/proc"
mount -t sysfs sysfs "${CHROOT_DIR}/sys"

echo "[3/6] Configuring Repositories & Installing Packages..."
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
export DEBCONF_NONINTERACTIVE_SEEN=true
echo "debconf debconf/frontend select Noninteractive" | debconf-set-selections
echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections || true

apt-get update

# Install all packages in a single high-speed transaction
PACKAGES=$(grep -v '^#' /tmp/packages.list | grep -v '^$' | tr '\n' ' ')
apt-get install -y --no-install-recommends ${PACKAGES}

# Run desktop setup
/tmp/setup-desktop.sh || true
rm -f /tmp/packages.list /tmp/setup-desktop.sh

# Setup Live User
useradd -m -s /bin/bash -G sudo,adm,dialout,cdrom,audio,dip,video,plugdev f77 || true
echo "f77:f77" | chpasswd
echo "f77 ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/f77
chmod 0440 /etc/sudoers.d/f77

# Force update initramfs with Casper live hooks
echo "[F77 OS] Updating initramfs with Casper hooks..."
update-initramfs -u -k all

# Clean apt cache to reduce ISO size
apt-get autoremove -y || true
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
EOF

echo "[4/6] Extracting Kernel & Initrd for Live Boot..."
mkdir -p "${IMAGE_DIR}/casper"
VMLINUZ=$(ls -1 "${CHROOT_DIR}/boot/vmlinuz-"* 2>/dev/null | head -n 1 || true)
INITRD=$(ls -1 "${CHROOT_DIR}/boot/initrd.img-"* 2>/dev/null | head -n 1 || true)

if [ -z "${VMLINUZ}" ] || [ -z "${INITRD}" ]; then
    echo "ERROR: Kernel or initrd not found in ${CHROOT_DIR}/boot!"
    ls -la "${CHROOT_DIR}/boot" || true
    exit 1
fi

cp "${VMLINUZ}" "${IMAGE_DIR}/casper/vmlinuz"
cp "${INITRD}" "${IMAGE_DIR}/casper/initrd"

echo "[CRITICAL FIX] Unmounting all virtual filesystems BEFORE SquashFS..."
umount -lf "${CHROOT_DIR}/dev/pts" || true
umount -lf "${CHROOT_DIR}/dev" || true
umount -lf "${CHROOT_DIR}/run" || true
umount -lf "${CHROOT_DIR}/proc" || true
umount -lf "${CHROOT_DIR}/sys" || true

# Recreate empty mountpoints so live-boot can mount them at boot
mkdir -p "${CHROOT_DIR}/dev" "${CHROOT_DIR}/proc" "${CHROOT_DIR}/sys" "${CHROOT_DIR}/run"

echo "[5/6] Compressing Root Filesystem into SquashFS (High-Speed Multi-Core)..."
mksquashfs "${CHROOT_DIR}" "${IMAGE_DIR}/casper/filesystem.squashfs" \
    -comp gzip -Xcompression-level 3 \
    -processors "${NUM_CORES}" \
    -e boot \
    -e proc \
    -e sys \
    -e dev \
    -e run \
    -e tmp \
    -noappend

echo "[6/6] Setting Up GRUB & Building Hybrid ISO with grub-mkrescue..."
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

grub-mkrescue -o "${ISO_NAME}" "${IMAGE_DIR}" -- -volid "F77_OS_LIVE"

sha256sum "${ISO_NAME}" > "${ISO_NAME}.sha256"

echo "============================================================"
echo "          F77 OS BUILD COMPLETED SUCCESSFULLY!              "
echo "  Output: ${ISO_NAME}                                       "
echo "  Checksum: $(cat "${ISO_NAME}.sha256")                     "
echo "============================================================"
