#!/bin/bash
case "${XDG_CURRENT_DESKTOP,,}" in
    niri)
        exec waybar --config "$HOME/.config/waybar/niri.config.jsonc"
        ;;
    hyprland)
        exec waybar --config "$HOME/.config/waybar/hyprland.config.jsonc"
        ;;
    *)
        exec waybar
        ;;
esac
