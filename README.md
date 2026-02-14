# Fedora Hyprland Setup

A curated Hyprland setup for Fedora laptops that focuses on daily use: fast boot into a complete desktop with notifications, audio controls, app launchers, and a consistent theme.

## Product overview
- Compositor: Hyprland with sensible defaults and laptop-friendly bindings.
- UI shell: Waybar, Rofi, Kitty, and Matugen-driven theming.
- Daily use: notifications (Mako), screenshots (Swappy), lock/idle, Bluetooth, and network applets.
- A wallpaper helper (`wallgen`) to recolor your UI from any image.

## Highlights
- Hyprland defaults with autostart for Waybar, swww, Mako, and applets in [.config/hypr/hyprland.conf](.config/hypr/hyprland.conf)
- Matugen templates in [.config/matugen/templates](.config/matugen/templates/hyprland-colours.conf)
- Waybar layout in [.config/waybar/config.jsonc](.config/waybar/config.jsonc)
- Rofi launcher theme in [.config/rofi/launchers/type-7/style-7.rasi](.config/rofi/launchers/type-7/style-7.rasi)
- Power menu with lock/sleep/reboot/shutdown in [.config/rofi/powermenu.sh](.config/rofi/powermenu.sh)
- Idle/lock settings in [.config/hypr/hypridle.conf](.config/hypr/hypridle.conf) and [.config/hypr/hyprlock.conf](.config/hypr/hyprlock.conf)
- Notifications in [.config/mako/config](.config/mako/config)
- Screenshot defaults in [.config/swappy/config](.config/swappy/config)

## Requirements
- Fedora 39 or newer.
- A Wayland-capable GPU.
- A display manager with a Hyprland session available.

## Compatibility and hardware independence
This setup is designed to work on any Fedora laptop, but a few values are hardware dependent and may need tweaks:
- Display: the monitor name, resolution, and refresh rates are configurable (`MONITOR_NAME`, `MONITOR_RESOLUTION`, `MONITOR_REFRESH_BAT`, `MONITOR_REFRESH_AC`).
- Network interface: Waybar defaults to `wlp4s0`; update if your Wi-Fi interface differs.
- GPU: `GPU_VENDOR=auto` detects NVIDIA/AMD/Intel. NVIDIA users can enable RPM Fusion drivers and Wayland overrides.
- Power detection: refresh switching uses power_supply entries of type `Mains`. If your system does not expose a Mains entry, you can disable battery tuning.

If you set the above values, the installer is hardware independent and safe to run on any Fedora laptop.

## Quick start
1) From a fresh Fedora install, clone this repo and run the installer as your regular user (do not run as root):
   ```bash
   chmod +x install.sh
   ./install.sh
   ```
2) Log out and choose the Hyprland session in your display manager.
3) Set a wallpaper and recolor the system:
   ```bash
   wallgen ~/Pictures/Wallpapers/your-image.jpg
   ```

After install, follow the validation checklist in [TEST_PLAN.md](TEST_PLAN.md) to confirm daily-use features.

`wallgen` starts `swww` if needed, updates the Rofi background line, and prints a single-line success or failure message.

The installer prints a log file path (for example: `/tmp/fedora-hyprland-XXXX.log`) to share on failures.

## Installer switches
Pass these as environment variables before running `./install.sh`:
- `INSTALL_CHROME=true|false` (default: true)
- `INSTALL_VSCODE=true|false` (default: true)
- `INSTALL_MATUGEN_METHOD=cargo|skip` (default: cargo)
- `SYSTEM_UPGRADE=true|false` (default: false)
- `INSTALL_WEAK_DEPS=true|false` (default: false)
- `INSTALL_NERD_FONT=true|false` (default: true)
- `ENABLE_BATTERY_TUNING=true|false` (default: true)
- `MONITOR_NAME`, `MONITOR_RESOLUTION`, `MONITOR_REFRESH_BAT`, `MONITOR_REFRESH_AC`
- `GPU_VENDOR=auto|nvidia|amd|intel|unknown`
- `ENABLE_NVIDIA_ENV=false`
- `DRY_RUN=true`

## Daily-use checklist
- Wi-Fi and VPN via NetworkManager applet.
- Bluetooth pairing via Blueman, with status in Waybar.
- Notifications through Mako.
- Audio/mic keys and `pavucontrol` on click.
- Screen lock with Super+L and idle lock after 5 minutes.
- Screenshot with Print and edit in Swappy.

## Configuration notes
- Waybar network interface defaults to `wlp4s0`; update in [.config/waybar/config.jsonc](.config/waybar/config.jsonc#L24).
- Default apps in Hyprland bindings: Kitty, Nautilus, Chrome, and VS Code. Update `$browser`, `$fileManager`, and `$ide` in [.config/hypr/hyprland.conf](.config/hypr/hyprland.conf#L26-L31).
- Wallpapers are expected under `~/Pictures/Wallpapers` (created by the installer).
- Screenshots save to `~/Pictures/Screenshots` by default.
- Re-running the installer is safe; PATH updates are idempotent.

## Uninstall / rollback
The installer does not remove packages automatically, but it always backs up overwritten configs.

To restore previous configs:
1) Locate the newest backup folder (for example: `~/.config.backup-YYYYMMDDHHMMSS`).
2) Copy contents back into `~/.config`.

To remove packages, use `dnf` to remove items you do not want (for example: `hyprland`, `waybar`, `rofi`, `kitty`, `swww`, `matugen`, `tlp`).

## Repo layout
- Hyprland: [.config/hypr](.config/hypr)
- Kitty: [.config/kitty](.config/kitty)
- Matugen: [.config/matugen](.config/matugen)
- Rofi: [.config/rofi](.config/rofi)
- Waybar: [.config/waybar](.config/waybar)
- Swappy: [.config/swappy](.config/swappy)
- Power menu: [.config/rofi/powermenu.sh](.config/rofi/powermenu.sh)
- Wallpaper helper: generated at `~/.local/bin/wallgen`
- Wallpapers: [Wallpapers](Wallpapers) copied to `~/Pictures/Wallpapers`
- All configs sync from this repo's `.config/` into `~/.config/`
