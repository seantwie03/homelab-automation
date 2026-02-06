#!/bin/sh
chosen=$(printf "  Shutdown\n  Reboot\n  Suspend" | wofi -d -i -p "Power Menu")

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
