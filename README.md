# HyprSutra

### A curated, Fedora-first Hyprland setup for daily use

**HyprSutra** is a structured Hyprland environment designed specifically for Fedora laptops.
It focuses on stability, reproducibility, and daily usability not just aesthetics.

Boot into a complete desktop with notifications, audio controls, network applets, lock/idle management, and a consistent theme.

---

## 🧭 Philosophy

“Sutra” means principles or structured guidelines.

HyprSutra is built on three core principles:

* Minimal but complete
* Hardware-aware
* Reproducible and debuggable

This is not a black-box rice.
It is a system you understand and control.

---

## 🧩 Product Overview

* **Compositor**: Hyprland with sensible, laptop-friendly defaults
* **UI Shell**: Waybar, Rofi, Kitty, Matugen-driven theming
* **Notifications**: Mako
* **Screenshots**: Swappy
* **Lock & Idle**: hypridle + hyprlock
* **Applets**: NetworkManager + Bluetooth integration
* **Wallpaper Engine**: `wallgen` helper for dynamic recoling

Designed to boot directly into a complete daily-use Wayland desktop.

---

## ✨ Highlights

* Hyprland autostart configuration in `.config/hypr/hyprland.conf`
* Matugen templates in `.config/matugen/templates`
* Waybar layout in `.config/waybar/config.jsonc`
* Rofi launcher theme in `.config/rofi/launchers/type-7`
* Custom power menu (`lock / sleep / reboot / shutdown`)
* Idle and lock configs in `.config/hypr/hypridle.conf`
* Notifications configured via Mako
* Screenshot workflow via Swappy
* Idempotent installer (safe to re-run)
* Automatic log file generation on failure

---

## 🖥 Requirements

* Fedora 39 or newer (tested on Fedora 43)
* Wayland-capable GPU
* A display manager with a Hyprland session available

---

## ⚙ Compatibility & Hardware Awareness

HyprSutra is designed to work on any Fedora laptop, but a few values are hardware dependent:

### Display

Configurable:

* `MONITOR_NAME`
* `MONITOR_RESOLUTION`
* `MONITOR_REFRESH_BAT`
* `MONITOR_REFRESH_AC`

### Network

Waybar defaults to `wlp4s0` (change if your Wi-Fi interface differs).

### GPU

`GPU_VENDOR=auto` detects:

* NVIDIA
* AMD
* Intel

NVIDIA users can enable RPM Fusion drivers and Wayland overrides.

### Power Detection

Refresh switching uses `power_supply` entries of type `Mains`.
If your system does not expose a Mains entry, battery tuning can be disabled.

Once these values are set, the installer is hardware-independent and safe to run on any Fedora laptop.

---

## 🚀 Quick Start

From a fresh Fedora install:

```bash
chmod +x install.sh
./install.sh
```

Run as your regular user (do not use root).

Then:

1. Log out
2. Choose the Hyprland session in your display manager
3. Set a wallpaper and recolor the system:

```bash
wallgen ~/Pictures/Wallpapers/image-name.png
```

`wallgen` will:

* Start `swww` if needed
* Update Rofi background
* Recolor UI via Matugen
* Print a single-line success/failure message

After installation, follow the validation checklist in `TEST_PLAN.md`.

---

## 🔧 Installer Switches

Pass these as environment variables before running `./install.sh`:

* `INSTALL_CHROME=true|false` (default: true)
* `INSTALL_VSCODE=true|false` (default: true)
* `INSTALL_MATUGEN_METHOD=cargo|skip`
* `SYSTEM_UPGRADE=true|false`
* `INSTALL_WEAK_DEPS=true|false`
* `INSTALL_NERD_FONT=true|false`
* `ENABLE_BATTERY_TUNING=true|false`
* `MONITOR_NAME`
* `MONITOR_RESOLUTION`
* `MONITOR_REFRESH_BAT`
* `MONITOR_REFRESH_AC`
* `GPU_VENDOR=auto|nvidia|amd|intel|unknown`
* `ENABLE_NVIDIA_ENV=false`
* `DRY_RUN=true`

---

## 📋 Daily-Use Checklist

* Wi-Fi and VPN via NetworkManager applet
* Bluetooth pairing via Blueman
* Notifications through Mako
* Audio/mic keys integrated with Waybar
* Screen lock with `Super + L`
* Idle lock after 5 minutes
* Screenshot with `Print` → edit in Swappy

---

## 🗂 Repo Layout

* Hyprland → `.config/hypr`
* Waybar → `.config/waybar`
* Rofi → `.config/rofi`
* Kitty → `.config/kitty`
* Matugen → `.config/matugen`
* Swappy → `.config/swappy`
* Wallpapers → `Wallpapers/`
* Wallpaper helper → `~/.local/bin/wallgen`

All configs sync from this repo’s `.config/` into `~/.config/`.

---

## 🔄 Uninstall / Rollback

HyprSutra backs up overwritten configs automatically.

To restore:

1. Locate latest backup folder
   `~/.config.backup-YYYYMMDDHHMMSS`
2. Copy contents back into `~/.config`

Packages can be removed via `dnf`.

---

## 🧠 Why HyprSutra?

Because ricing should not be:

* Fragile
* Bloated
* Black-boxed

It should be:

* Structured
* Minimal
* Understandable
* Reproducible

HyprSutra is not just a theme.
It is a system layer for Fedora + Hyprland.
