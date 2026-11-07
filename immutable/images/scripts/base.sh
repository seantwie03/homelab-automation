#!/usr/bin/env bash
# Installs the command-line tools every host uses that the base image lacks.
set -euo pipefail

# Fedora's wget is wget2-wget, and 7zip provides 7z and 7za.
dnf install -y \
    wget2-wget \
    7zip \
    kitty-terminfo
dnf clean all
# bootc copies /var from the image only on first install, so leave nothing
# there or in /run.
rm -rf /var/log/dnf5.log /var/cache/libdnf5 /var/cache/ldconfig /var/lib/dnf \
    /run/dnf
