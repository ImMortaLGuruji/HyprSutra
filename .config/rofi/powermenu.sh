#!/usr/bin/env bash
set -euo pipefail

menu_items="Shutdown\nReboot\nLock\nSleep"
choice=$(printf "%b" "$menu_items" | rofi -dmenu -p "Power" -theme "$HOME/.config/rofi/launchers/type-7/style-7.rasi")

case "$choice" in
  Lock)
    hyprlock
    ;;
  Sleep)
    systemctl suspend
    ;;
  Reboot)
    systemctl reboot
    ;;
  Shutdown)
    systemctl poweroff
    ;;
  *)
    exit 0
    ;;
esac
