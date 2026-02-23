#!/usr/bin/env bash
set -euo pipefail

wall_dir="$HOME/Pictures/Wallpapers"
repo_dir="$HOME/Documents/GitHub/FedoraHyprlandSetup/Wallpapers"
wallgen_bin="$HOME/.local/bin/wallgen"

if [[ ! -d "$wall_dir" ]] && [[ -d "$repo_dir" ]]; then
  wall_dir="$repo_dir"
fi

if [[ ! -d "$wall_dir" ]]; then
  exit 1
fi

entries=$(find "$wall_dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -printf '%f\n' | sort)
if [[ -z "$entries" ]]; then
  exit 1
fi

current_wall=$(swww query 2>/dev/null | awk -F 'image: ' '/image: /{print $2; exit}')
theme_bg_str=""
if [[ -n "$current_wall" ]]; then
  current_wall_escaped=$(printf '%s\n' "$current_wall" | sed 's/["\\]/\\&/g')
  theme_bg_str="inputbar { background-image: url(\"${current_wall_escaped}\", height); }"
fi

choice=$(while IFS= read -r file; do
  printf '%s\x00icon\x1f%s\n' "$file" "$wall_dir/$file"
done <<< "$entries" | rofi -dmenu -i -show-icons -p "Wallpapers" \
  -theme "$HOME/.config/rofi/launchers/type-7/style-7.rasi" \
  -theme-str "configuration { show-icons: true; } ${theme_bg_str}")

if [[ -z "$choice" ]]; then
  exit 0
fi

selected="$wall_dir/$choice"
if [[ ! -f "$selected" ]]; then
  exit 1
fi

"$wallgen_bin" "$selected"
