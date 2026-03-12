#!/usr/bin/env bash
# Pick a previously downloaded vid-play video and open it in mpv.

files=$(ls /tmp/vid-play* 2>/dev/null | xargs basename -a 2>/dev/null)

[ -z "$files" ] && exit 0

selected=$(echo "$files" | fuzzel --dmenu --prompt="Open Video > ")

[ -n "$selected" ] && mpv "/tmp/$selected"
