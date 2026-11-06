# Core

Publishes `is_graphical_system`, which is true when the host's default systemd
target is `graphical.target`. Other roles use this fact to gate
graphical-only configuration.

The baseline utilities this role installs on traditional hosts, such as
downloader and archive tools, `usbutils`, `kitty-terminfo`, and Intel CPU
microcode, come from the image instead. The base image ships most of them, and
`images/scripts/base.sh` adds the rest.
