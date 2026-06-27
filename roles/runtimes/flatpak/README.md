# Flatpak

Installs Flatpak support for graphical applications.

This role installs the `flatpak` package, adds the Flathub system remote,
creates `/var/lib/flatpak/overrides` so other roles can manage system-wide
Flatpak permissions, and installs Flatseal when `is_graphical_system` is true.

Roles that install Flatpak applications should depend on this role instead of
configuring Flathub themselves.
