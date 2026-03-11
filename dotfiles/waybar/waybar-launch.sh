#!/bin/bash
case "${XDG_CURRENT_DESKTOP,,}" in
    niri)
        exec waybar --config "$HOME/.config/waybar/niri.config.jsonc"
        ;;
    hyprland)
        exec waybar --config "$HOME/.config/waybar/hyprland.config.jsonc"
        ;;
    *)
        exit # Probably running KDE or something
        ;;
esac
