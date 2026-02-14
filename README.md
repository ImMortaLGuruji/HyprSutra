# Fedora Hyprland Setup

Opinionated Hyprland setup for Fedora laptops with a polished daily‑use experience: notifications, tray applets, lock screen, and consistent theming.

## Highlights
- Clean Hyprland defaults with key daily‑use services autostarting in [.config/hypr/hyprland.conf](.config/hypr/hyprland.conf)
- Theming via Matugen templates in [.config/matugen/templates](.config/matugen/templates/hyprland-colours.conf)
- Waybar with Bluetooth, tray, and laptop‑friendly modules in [.config/waybar/config.jsonc](.config/waybar/config.jsonc)
- Rofi launcher with wallpaper‑backed theme in [.config/rofi/launchers/type-7/style-7.rasi](.config/rofi/launchers/type-7/style-7.rasi)
- Idle + lock config for laptops in [.config/hypr/hypridle.conf](.config/hypr/hypridle.conf) and [.config/hypr/hyprlock.conf](.config/hypr/hyprlock.conf)
- Notifications via Mako in [.config/mako/config](.config/mako/config)
- `wallgen` helper (installed to `~/.local/bin/wallgen`) to set wallpaper, recolor, and sync Rofi

## Quick start
1) From a fresh Fedora 39+ install, clone this repo and run the installer as your regular user (do not run as root):
   ```bash
   chmod +x install.sh
   ./install.sh
   ```
2) Log out and choose the Hyprland session in your display manager.
3) Set a wallpaper and recolor the system:
   ```bash
   wallgen ~/Pictures/Wallpapers/your-image.jpg
   ```

`wallgen` starts `swww` if needed, updates the Rofi background line, and prints a single‑line success or failure message.

The installer prints a log file path (for example: `/tmp/fedora-hyprland-XXXX.log`) to share on failures.

## Installer switches
Pass these as environment variables before running `./install.sh`.
- `INSTALL_CHROME=true|false` (default: true)
- `INSTALL_VSCODE=true|false` (default: true)
- `INSTALL_MATUGEN_METHOD=cargo|skip` (default: cargo)
- `ENABLE_BATTERY_TUNING=true|false` (default: true)
- `MONITOR_NAME`, `MONITOR_RESOLUTION`, `MONITOR_REFRESH_BAT`, `MONITOR_REFRESH_AC`
- `GPU_VENDOR=auto|nvidia|amd|intel|unknown` (auto detects via `lspci`)
- `ENABLE_NVIDIA_ENV=false` to skip NVIDIA Wayland overrides
- `DRY_RUN=true` to preview rsync‑based copies and backups

## Daily‑use checklist
- Wi‑Fi and VPN from the NetworkManager tray applet.
- Bluetooth pairing from Blueman and status in Waybar.
- Notifications through Mako.
- Audio and mic keys, with `pavucontrol` on click.
- Screen lock with $mainMod+L and idle lock after 5 minutes.
- Screenshot with Print (selection) and edit in Swappy.

## Notes for reviewers
- Install is non‑root, uses sudo only when required, and produces a single log file.
- Config deployment is rsync‑based with timestamped backups for safe rollback.
- The setup targets Fedora 39+ and uses COPR for Hyprland and swww.

## Notes for users
- Waybar network interface defaults to `wlp4s0`; update the interface in [.config/waybar/config.jsonc](.config/waybar/config.jsonc#L24) if needed.
- Default apps in Hyprland bindings: Kitty, Nautilus, Google Chrome, and VS Code. Update `$browser`, `$fileManager`, and `$ide` in [.config/hypr/hyprland.conf](.config/hypr/hyprland.conf#L26-L31).
- Wallpapers are expected under `~/Pictures/Wallpapers` (created by the installer).
- Re‑running the installer is safe; PATH updates are idempotent.
- If using NVIDIA, set `GPU_VENDOR=nvidia` for RPM Fusion + akmod drivers.

## Uninstall / rollback
The installer does not remove packages automatically, but it always backs up overwritten configs.

To restore your previous configs:
1) Locate the newest backup folder (for example: `~/.config.backup-YYYYMMDDHHMMSS`).
2) Copy the contents you want back into `~/.config`.

To remove installed packages, use `dnf` to remove items you do not want (for example: `hyprland`, `waybar`, `rofi`, `kitty`, `swww`, `matugen`, `tlp`).

## Repo layout
- Hyprland: [.config/hypr](.config/hypr)
- Kitty: [.config/kitty](.config/kitty)
- Matugen: [.config/matugen](.config/matugen)
- Rofi: [.config/rofi](.config/rofi)
- Waybar: [.config/waybar](.config/waybar)
- Wallpaper helper: generated at `~/.local/bin/wallgen`
- Wallpapers: [Wallpapers](Wallpapers) copied to `~/Pictures/Wallpapers`
- All configs sync from this repo’s `.config/` into `~/.config/`
