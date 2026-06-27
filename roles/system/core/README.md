# Core

Installs baseline utilities expected on managed Fedora and RHEL systems.

This role installs downloader tools, archive tools, Ansible module
prerequisites, `usbutils`, `kitty-terminfo`, and Intel CPU microcode where
applicable.

On Intel x86_64 systems, installing or updating `microcode_ctl` notifies the
handler that rebuilds the current kernel initramfs.

