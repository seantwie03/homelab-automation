#!/usr/bin/env bash
# Installs what ansible-pull needs on a booted host: git, Python, ansible-core,
# and the Ansible collections that runtime roles use. Collections come from
# Fedora packages, which install them to /usr/share/ansible/collections.
set -euo pipefail

dnf install -y \
    git \
    python3 \
    ansible-core \
    ansible-collection-ansible-posix
dnf clean all
# bootc copies /var from the image only on first install, so leave nothing
# there or in /run.
rm -rf /var/log/dnf5.log /var/cache/libdnf5 /var/cache/ldconfig /var/lib/dnf \
    /run/dnf
