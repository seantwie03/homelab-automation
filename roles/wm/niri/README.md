# Niri

Installs and configures a Niri Wayland session.

This role manages:

- The `niri` compositor and supporting desktop packages.
- `nautilus`, `pavucontrol`, `pulseaudio-utils`, `swayidle`, `swaylock`,
  `swaybg`, `gnome-calculator`, and Gradia.
- The Niri dotfile symlink at `~/.config/niri`.
- The host-specific `machine-specific.conf` symlink.
- A wallpaper under `~/.local/share/backgrounds`.
- The `niri_window_buttons` Waybar plugin build and install flow.
- `xdg-desktop-portal-wlr` and portal priority for Zoom screen sharing.
- `graphical.target` as the default systemd target.
- A `.bash_profile` block that starts the selected UWSM session.

## Dependencies

Niri depends on shared roles for Rust, Waybar, Dunst, Flatpak, Fuzzel,
Bluetooth, and screen annotation.

Host-specific Niri configuration should live in `dotfiles/niri/<hostname>.conf`.
The `niri_window_buttons_version` default controls which plugin tag is checked
out and built.

See `MONITORING.md` for session, portal, configuration, and Waybar plugin
checks.

