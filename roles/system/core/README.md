# Core

Installs baseline utilities expected on managed Fedora and RHEL systems.

This role installs downloader tools, archive tools, Ansible module
prerequisites, `usbutils`, `kitty-terminfo`, and Intel CPU microcode where
applicable.

It also publishes `is_graphical_system`, which is true when
`/etc/systemd/system/default.target` points at `graphical.target`. Other roles
can use this fact to gate graphical-only packages.

On Intel x86_64 systems, installing or updating `microcode_ctl` notifies the
handler that rebuilds the current kernel initramfs.
