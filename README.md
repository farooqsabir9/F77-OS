# F77 OS

> **The Next-Generation Open-Source Hybrid Operating System**
> Combining the power of Linux, native Android app execution, Windows (.exe) compatibility, macOS toolchains, and Kali Linux cybersecurity tools into a unified, stunning Mac + Windows 11 hybrid desktop interface.

---

## 🌟 Key Architecture & Features

```
┌────────────────────────────────────────────────────────────────────────┐
│                        F77 HYBRID DESKTOP UI                           │
│        (KDE Plasma: macOS Top Global Bar + Windows 11 Centered Dock)   │
├──────────────┬──────────────┬──────────────┬───────────────────────────┤
│   Android    │   Windows    │  macOS CLI   │        Kali Linux         │
│  (Waydroid)  │(Wine+Bottles)│  (Darling)   │     Security Suite        │
├──────────────┴──────────────┴──────────────┴───────────────────────────┤
│               Debian / Ubuntu LTS (Noble Numbat) Core                  │
├────────────────────────────────────────────────────────────────────────┤
│                       Linux Kernel 6.8+ (x86_64)                       │
└────────────────────────────────────────────────────────────────────────┘
```

1. **Hybrid Visual Design:**
   - **macOS Inspiration:** Top global panel, system status icons, media widget, blur/glassmorphism aesthetics.
   - **Windows 11 Inspiration:** Centered floating taskbar/dock, modern quick-settings panel, integrated start menu.
2. **Android Execution Engine (Waydroid):**
   - Direct LXC container virtualization running pure Android directly on the Linux kernel with hardware GPU acceleration.
3. **Windows Software Support (Wine + Bottles):**
   - Run `.exe` and `.msi` applications and games out of the box.
4. **macOS Compatibility Layer (Darling):**
   - Translate Mach-O Darwin binaries and run macOS CLI tools directly.
5. **Cybersecurity & Pentesting Toolkit:**
   - Built-in Kali Linux security toolchains (`nmap`, `wireshark`, `aircrack-ng`, `metasploit`, etc.).

---

## ⚡ Cloud Automated Build (GitHub Actions)

This repository includes a fully automated **GitHub Actions CI/CD pipeline** (`.github/workflows/build-iso.yml`) that builds the bootable **F77-OS-amd64.iso** on high-performance cloud servers without consuming local PC resources.

### How to Trigger the Build:
1. Push this repository to `github.com/farooqsabir9/F77-OS`.
2. Go to the **Actions** tab on GitHub.
3. Select **Build F77 OS Live ISO** and click **Run workflow**.
4. Once completed (approx. 20-25 mins), download the `F77-OS-v1.0-amd64.iso` directly from the **Releases** or **Artifacts** section!

---

## 💻 Running & Installing F77 OS
Burn the ISO to a USB flash drive (minimum 8GB) using:
* **Rufus** (Windows)
* **Ventoy** (Multi-boot)
* **BalenaEtcher** (Mac / Linux / Windows)

Boot in **UEFI** or **Legacy BIOS** mode. F77 OS supports Live-Boot (try without installing) and permanent installation via Calamares installer.

