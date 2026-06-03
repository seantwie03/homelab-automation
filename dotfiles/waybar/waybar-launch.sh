#!/bin/bash
case "${XDG_CURRENT_DESKTOP,,}" in
    niri)
        host_config="$HOME/.config/waybar/niri.$(hostname --short).config.jsonc"
        host_style="$HOME/.config/waybar/niri.$(hostname --short).style.css"
        if [ -f "$host_config" ]; then
            if [ -f "$host_style" ]; then
                exec waybar --config "$host_config" --style "$host_style"
            fi
            exec waybar --config "$host_config"
        fi
        exec waybar --config "$HOME/.config/waybar/niri.config.jsonc"
        ;;
    hyprland)
        exec waybar --config "$HOME/.config/waybar/hyprland.config.jsonc"
        ;;
    *)
        exit # Probably running KDE or something
        ;;
esac
