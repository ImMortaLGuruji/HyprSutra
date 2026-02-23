#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="$HOME/.cache/hypr"
STATE_FILE="$STATE_DIR/battery-mode"
BRIGHTNESS_FILE="$STATE_DIR/battery-brightness"
SETTINGS_FILE="$STATE_DIR/battery-mode-settings"

mkdir -p "$STATE_DIR"

get_current_brightness() {
  brightnessctl -m | awk -F, '{print $4}' | tr -d '%'
}

set_brightness() {
  local value="$1"
  brightnessctl set "${value}%" >/dev/null 2>&1 || true
}

set_animations() {
  local value="$1"
  if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl keyword animations:enabled "$value" >/dev/null 2>&1 || true
    return
  fi
  hyprctl keyword animations:enabled "$value" >/dev/null 2>&1 || true
}

set_option() {
  local key="$1"
  local value="$2"
  hyprctl keyword "$key" "$value" >/dev/null 2>&1 || true
}

get_option_value() {
  local key="$1"
  hyprctl getoption "$key" 2>/dev/null | awk '/(int|float):/ {print $2; exit}'
}

save_settings() {
  if [[ -f "$SETTINGS_FILE" ]]; then
    return
  fi

  {
    echo "animations_enabled=$(get_option_value animations:enabled)"
    echo "blur_enabled=$(get_option_value decoration:blur:enabled)"
    echo "blur_size=$(get_option_value decoration:blur:size)"
    echo "blur_passes=$(get_option_value decoration:blur:passes)"
    echo "shadow_enabled=$(get_option_value decoration:shadow:enabled)"
  } > "$SETTINGS_FILE"
}

load_setting() {
  local key="$1"
  if [[ ! -f "$SETTINGS_FILE" ]]; then
    return
  fi
  awk -F= -v k="$key" '$1 == k {print $2; exit}' "$SETTINGS_FILE"
}

set_hypr_signature() {
  local runtime_dir sig_dir
  runtime_dir="/run/user/$(id -u)"
  sig_dir=$(ls -1d "$runtime_dir"/hypr/* 2>/dev/null | head -n1 || true)
  if [[ -n "$sig_dir" ]]; then
    export HYPRLAND_INSTANCE_SIGNATURE="$(basename "$sig_dir")"
  fi
}

apply_battery_mode() {
  local current
  set_hypr_signature
  save_settings
  current=$(get_current_brightness || echo "")
  if [[ -n "$current" ]]; then
    echo "$current" > "$BRIGHTNESS_FILE"
  fi
  set_brightness 40
  set_animations 0
  set_option decoration:blur:enabled 0
  set_option decoration:shadow:enabled 0
  echo "on" > "$STATE_FILE"
}

restore_mode() {
  local animations blur_enabled blur_size blur_passes shadow_enabled
  set_hypr_signature
  if [[ -f "$BRIGHTNESS_FILE" ]]; then
    set_brightness "$(cat "$BRIGHTNESS_FILE")"
  fi
  animations=$(load_setting animations_enabled)
  blur_enabled=$(load_setting blur_enabled)
  blur_size=$(load_setting blur_size)
  blur_passes=$(load_setting blur_passes)
  shadow_enabled=$(load_setting shadow_enabled)

  if [[ -n "$animations" ]]; then
    set_animations "$animations"
  else
    set_animations 1
  fi
  if [[ -n "$blur_size" ]]; then
    set_option decoration:blur:size "$blur_size"
  fi
  if [[ -n "$blur_passes" ]]; then
    set_option decoration:blur:passes "$blur_passes"
  fi
  if [[ -n "$blur_enabled" ]]; then
    set_option decoration:blur:enabled "$blur_enabled"
  fi
  if [[ -n "$shadow_enabled" ]]; then
    set_option decoration:shadow:enabled "$shadow_enabled"
  fi
  rm -f "$STATE_FILE"
  rm -f "$SETTINGS_FILE"
}

case "${1:-toggle}" in
  on)
    apply_battery_mode
    ;;
  off)
    restore_mode
    ;;
  toggle)
    if [[ -f "$STATE_FILE" ]]; then
      restore_mode
    else
      apply_battery_mode
    fi
    ;;
  *)
    echo "Usage: $0 [on|off|toggle]" >&2
    exit 1
    ;;
esac
