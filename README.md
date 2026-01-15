# Fedora Hyprland Setup

Hyprland dotfiles for Fedora with Waybar, Rofi, Kitty, Matugen-driven theming, and a `wallgen` helper to rotate wallpapers and recolor the desktop.

## What you get
- Hyprland configuration with autostart for Waybar and `swww` in [.config/hypr/hyprland.conf](.config/hypr/hyprland.conf)
- Matugen templates that recolor Hyprland, Kitty, Rofi, and Waybar in [.config/matugen/templates](.config/matugen/templates/hyprland-colours.conf)
- Waybar layout and styling tuned for Material-derived colors in [.config/waybar](.config/waybar/config.jsonc)
- Rofi launcher theme with wallpaper backdrop in [.config/rofi/launchers/type-7/style-7.rasi](.config/rofi/launchers/type-7/style-7.rasi)
- `wallgen` helper to set a wallpaper, run Matugen, and sync Rofi’s background in [wallgen](wallgen)

## Quick start
1) From a fresh Fedora install, clone this repo and run the installer:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```
   Optional flags:
   - `INSTALL_CHROME=false` to skip Google Chrome
   - `INSTALL_VSCODE=false` to skip VS Code
   - `INSTALL_MATUGEN_METHOD=skip` to skip building Matugen with cargo

2) Log out and choose the **Hyprland** session in your display manager.

3) Set a wallpaper and recolor the system:
   ```bash
   wallgen ~/Pictures/Wallpapers/your-image.jpg
   ```

## Notes and adjustments
- Waybar network interface defaults to `wlp4s0`; update `"interface"` in [.config/waybar/config.jsonc](.config/waybar/config.jsonc#L24) to match your device.
- Default apps in Hyprland bindings: Kitty, Nautilus, Google Chrome, and VS Code. Change `$browser`, `$fileManager`, and `$ide` in [.config/hypr/hyprland.conf](.config/hypr/hyprland.conf#L26-L31) if you prefer alternatives.
- Wallpaper paths inside Matugen output and the Rofi theme expect files under `~/Pictures/Wallpapers`. The installer creates this folder for you.
- The installer backs up any existing configs it overwrites to a timestamped folder in your home directory.

## Repo layout
- Hyprland: [.config/hypr](.config/hypr)
- Kitty: [.config/kitty](.config/kitty)
- Matugen: [.config/matugen](.config/matugen)
- Rofi: [.config/rofi](.config/rofi)
- Waybar: [.config/waybar](.config/waybar)
- Wallpaper helper: [wallgen](wallgen) (installed to `~/.local/bin/wallgen` by the installer)
- Wallpapers: [Wallpapers](Wallpapers) copied to `~/Pictures/Wallpapers`
- All configs sync from this repo’s `.config/` into `~/.config/`

Happy tiling!
