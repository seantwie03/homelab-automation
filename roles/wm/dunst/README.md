# Dunst

Installs and enables Dunst for notification handling in lightweight window
manager sessions.

This role installs the `dunst` package, symlinks `dotfiles/dunst` to
`~/.config/dunst`, and enables the user `dunst.service`.

Roles for window managers that need a notification daemon should depend on this
role.

See `MONITORING.md` for service, notification delivery, log, and dotfile checks.

