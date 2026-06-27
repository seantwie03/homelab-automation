# Waybar

Installs and enables Waybar for Wayland window-manager sessions.

This role installs `waybar` and `gnome-calendar`, symlinks `dotfiles/waybar` to
`~/.config/waybar`, and enables the user `waybar.service`.

The role also installs a systemd user drop-in for `waybar.service` so the unit
uses the role-managed launch script from the Waybar dotfiles.

Window-manager roles that use Waybar should depend on this role.

See `MONITORING.md` for service, drop-in, dotfile, log, and plugin checks.

