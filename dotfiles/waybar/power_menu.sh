#!/bin/sh
chosen=$(printf "  Shutdown\n  Reboot\n  Suspend" | fuzzel --dmenu --prompt="Power Menu > ")

case "$chosen" in
    "  Shutdown")
        shutdown now
        ;;
    "  Reboot")
        reboot
        ;;
    "  Suspend")
        systemctl suspend
        ;;
esac
