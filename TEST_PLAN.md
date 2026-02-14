# Fedora Hyprland Post-Install Test Plan

Use this after reboot. Verify each item in order and mark Pass/Fail.

## 0) Session + baseline
- [ ] Login screen shows a **Hyprland** session.
- [ ] Hyprland starts without crashing.
- [ ] Waybar is visible.
- [ ] Rofi opens with `Super+M`.
- [ ] Terminal opens with `Super+Enter`.
- [ ] Power menu opens from the ⏻ tile.

Expected:
- No crash loops.
- Top bar visible with workspace/window modules.

---

## 1) Core input and keybinds
- [ ] `Super+Q` closes active window.
- [ ] `Super+F` opens Nautilus.
- [ ] `Super+B` opens browser.
- [ ] `Super+C` opens VS Code (if installed).
- [ ] `Super+1..0` switches workspaces.
- [ ] `Super+Shift+1..0` moves windows between workspaces.

Expected:
- All binds respond immediately.

---

## 2) Network and connectivity
- [ ] Left-click Wi‑Fi tile opens NetworkManager UI.
- [ ] Right-click Wi‑Fi tile opens `nmtui`.
- [ ] Can connect/disconnect Wi‑Fi from NetworkManager UI.
- [ ] VPN profile can be toggled from NetworkManager UI (if configured).

Expected:
- Waybar network module updates.
- No stuck “disconnected” state after connecting.

---

## 3) Bluetooth
- [ ] Bluetooth service is active.
- [ ] Blueman applet is visible.
- [ ] Pair a Bluetooth device.
- [ ] Waybar Bluetooth module reflects connected device.

Expected:
- Device pairs and reconnects successfully.

---

## 4) Audio + media keys
- [ ] Volume up/down keys work.
- [ ] Mute and mic mute keys work.
- [ ] `playerctl` media keys (play/pause/next/prev) work in browser/player.
- [ ] Clicking audio module opens `pavucontrol`.

Expected:
- Waybar volume status updates correctly.

---

## 5) Notifications
- [ ] Mako starts automatically.
- [ ] Trigger a notification (e.g., from browser/system app).

Expected:
- Notification appears with configured style and disappears normally.

---

## 6) Wallpaper + theming (`wallgen`)
- [ ] Run `wallgen` with a valid wallpaper path.
- [ ] It prints exactly one success line.
- [ ] Hyprland/Waybar/Rofi theme colors update.
- [ ] Rofi launcher background updates to selected wallpaper.

Negative checks:
- [ ] Invalid path returns one-line failure reason.

Expected:
- No verbose logs.
- One-line success/failure output only.

---

## 7) Screenshot workflow
- [ ] Press `Print`.
- [ ] Select a region.
- [ ] Swappy opens with captured image.
- [ ] Default save location is `~/Pictures/Screenshots`.

Expected:
- Screenshot path/workflow works without errors.

---

## 8) Lock and idle
- [ ] `Super+L` locks screen via Hyprlock.
- [ ] Idle lock triggers around 5 minutes.
- [ ] Display powers off around 10 minutes idle, wakes on input.

Expected:
- Unlock works reliably.
- No black screen lockout after wake.

---

## 9) Battery and refresh automation (if enabled)
- [ ] `tlp` service is active.
- [ ] AC plug/unplug triggers refresh profile switch.
- [ ] No errors from `hypr-refresh.service`.

Expected:
- Service runs cleanly and monitor refresh changes as configured. If auto switching fails, verify manual switch with `/usr/local/bin/hypr-refresh.sh`.

---

## 10) XDG portals and desktop integration
- [ ] Screen sharing picker works in browser/app.
- [ ] Clipboard copy/paste works across apps.
- [ ] File picker works normally in browser and VS Code.

Expected:
- No portal permission loops.

---

## 11) Optional GPU checks
### NVIDIA path
- [ ] Driver modules loaded.
- [ ] Wayland session remains stable.

### AMD/Intel path
- [ ] No rendering artifacts.
- [ ] Smooth compositor behavior.

---

## 12) Final sign-off
- [ ] Reboot once more and confirm autostart apps (Waybar, applets, mako, hypridle) return.
- [ ] No recurring errors in latest installer/runtime logs.

If any item fails, capture:
1) exact step,
2) observed behavior,
3) expected behavior,
4) relevant log snippet.
