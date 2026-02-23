#!/usr/bin/env bash
set -euo pipefail

menu_items="Shutdown\nReboot\nLock\nSleep"

current_wall=$(swww query 2>/dev/null | awk -F 'image: ' '/image: /{print $2; exit}')
theme_bg_str=""
if [[ -n "$current_wall" ]]; then
  current_wall_escaped=$(printf '%s\n' "$current_wall" | sed 's/["\\]/\\&/g')
  theme_bg_str="inputbar { background-image: url(\"${current_wall_escaped}\", height); }"
fi

choice=$(printf "%b" "$menu_items" | rofi -dmenu -p "Power" \
  -theme "$HOME/.config/rofi/launchers/type-7/style-7.rasi" \
  -theme-str "configuration { show-icons: true; } ${theme_bg_str}")

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
