#!/usr/bin/env bash
set -e

echo "[F77 OS] Configuring F77 Desktop & Subsystems..."

# 1. Enable Waydroid Repository
export DEBIAN_FRONTEND=noninteractive
curl -s https://repo.waydro.id | bash || true

# 2. Add Flatpak Flathub repository
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true

# 3. Configure Default Hostname & OS Branding
echo "f77-os" > /etc/hostname
sed -i 's/PRETTY_NAME=.*/PRETTY_NAME="F77 OS v1.0 (Hybrid Edition)"/' /etc/os-release
sed -i 's/NAME=.*/NAME="F77 OS"/' /etc/os-release
sed -i 's/ID=.*/ID=f77/' /etc/os-release

# 4. Create default user configuration for hybrid Mac+Win11 UI layout
mkdir -p /etc/skel/.config

# Setup KDE plasma desktop layout template
cat << 'EOF' > /etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc
[ActionPlugins][1]
RightButton;NoModifier=org.kde.contextmenu

[Containments][1]
activityId=
formfactor=0
immutability=1
lastScreen=0
location=0
plugin=org.kde.plasma.folder
wallpaperplugin=org.kde.image

[Containments][2]
# Top Panel (macOS Style: Global Menu, Clock, Status)
activityId=
formfactor=2
immutability=1
lastScreen=0
location=3
plugin=org.kde.panel

[Containments][3]
# Bottom Dock (Windows 11 Style: Floating Centered Taskbar)
activityId=
formfactor=2
immutability=1
lastScreen=0
location=4
plugin=org.kde.panel
alignment=center
EOF

# 5. Configure SDDM Autologin for Live Session (Critical for Plymouth to exit!)
mkdir -p /etc/sddm.conf.d
cat << 'EOF' > /etc/sddm.conf.d/autologin.conf
[Autologin]
User=f77
Session=plasma
Relogin=false
EOF

# 6. Create F77 Quick-Launch Helper for Android & Windows
cat << 'EOF' > /usr/local/bin/f77-android
#!/usr/bin/env bash
echo "Launching F77 Android Subsystem (Waydroid)..."
waydroid show-full-ui &
EOF
chmod +x /usr/local/bin/f77-android

cat << 'EOF' > /usr/local/bin/f77-pentest
#!/usr/bin/env bash
echo "=============================================="
echo "          F77 OS Security Suite               "
echo "=============================================="
echo "Installed tools: nmap, wireshark, aircrack-ng, sqlmap, hydra, nikto"
echo "Starting root pentesting shell..."
sudo bash
EOF
chmod +x /usr/local/bin/f77-pentest

echo "[F77 OS] Desktop & subsystem configuration completed successfully."
