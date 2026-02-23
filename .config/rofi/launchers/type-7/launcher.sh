#!/usr/bin/env bash

dir="$HOME/.config/rofi/launchers/type-7"
theme='style-7'

current_wall=$(swww query 2>/dev/null | awk -F 'image: ' '/image: /{print $2; exit}')
theme_bg_str=""
if [[ -n "$current_wall" ]]; then
    current_wall_escaped=$(printf '%s\n' "$current_wall" | sed 's/["\\]/\\&/g')
    theme_bg_str="inputbar { background-image: url(\"${current_wall_escaped}\", height); }"
fi

## Run
rofi \
    -show drun \
    -theme ${dir}/${theme}.rasi \
    -theme-str "${theme_bg_str}"
