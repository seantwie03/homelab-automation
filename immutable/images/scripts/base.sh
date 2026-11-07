#!/usr/bin/env bash
# Installs the command-line tools and services every host uses that the base
# image lacks. Runtime roles enable and configure the services.
set -euo pipefail

# Fedora's wget is wget2-wget, and 7zip provides 7z and 7za.
dnf install -y \
    wget2-wget \
    7zip \
    kitty-terminfo \
    tailscale
dnf clean all
# tailscale ships its state and cache directories under /var, which bootc
# copies only at install, so systemd-tmpfiles creates them at boot instead.
rm -rf /var/lib/tailscale /var/cache/tailscale
cat >/usr/lib/tmpfiles.d/tailscale-var.conf <<'CONF'
d /var/lib/tailscale 0700 root root -
d /var/cache/tailscale 0700 root root -
CONF
# bootc copies /var from the image only on first install, so leave nothing
# there or in /run.
rm -rf /var/log/dnf5.log /var/cache/libdnf5 /var/cache/ldconfig /var/lib/dnf \
    /run/dnf
