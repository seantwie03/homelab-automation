# Hyprland

Installs and configures a Hyprland Wayland session.

This role manages:

- The `lionheartp/Hyprland` COPR.
- `hyprland`, `hyprland-guiutils`, `hyprpaper`, `hypridle`, and `pavucontrol`.
- The Hyprland dotfile symlink at `~/.config/hypr`.
- The host-specific `machine-specific.conf` symlink.
- Gradia as the screenshot annotation Flatpak.
- `graphical.target` as the default systemd target.
- A `.bash_profile` block that starts the selected UWSM session.

## Dependencies

Hyprland depends on shared roles for Waybar, Dunst, Flatpak, Fuzzel, Bluetooth,
and screen annotation.

Host-specific Hyprland configuration should live in `dotfiles/hypr/<hostname>.conf`.

