#!/usr/bin/env bash
# Installs the command-line tools every host uses that the base image lacks.
set -euo pipefail

dnf install -y \
    wget \
    p7zip \
    kitty-terminfo
dnf clean all
# bootc copies /var from the image only on first install, so leave nothing
# there or in /run.
rm -rf /var/log/dnf5.log /var/cache/libdnf5 /var/cache/ldconfig /var/lib/dnf \
    /run/dnf
