# niri Role - Monitoring

## Session

Run these checks from the managed user's graphical login:

```sh
loginctl session-status
systemctl --user is-system-running
systemctl --user --failed --no-pager
pgrep -a niri
```

Expected:

- The active local session is Wayland.
- Niri is running through UWSM.
- No required user unit is failed.

UWSM creates generated target and application unit names. Inspect the actual
user unit graph rather than assuming a fixed `niri.service`.

## Configuration

```sh
niri validate
readlink -f ~/.config/niri
readlink -f ~/.config/niri/machine-specific.conf
```

Configuration should validate, and both links should resolve into this
repository with the machine-specific file matching the current hostname.

## Desktop Portals

```sh
systemctl --user status xdg-desktop-portal.service \
    xdg-desktop-portal-wlr.service --no-pager
systemctl --user --failed --no-pager
journalctl --user -u xdg-desktop-portal.service \
    -u xdg-desktop-portal-wlr.service -b --no-pager
cat ~/.config/xdg-desktop-portal/portals.conf
```

The configured preferred portal should be `wlr` with GTK fallback. Portal
failures affect screen sharing, screenshots, and file pickers even when the
compositor itself works.

## Waybar Plugin

```sh
test -r /usr/lib/waybar/libniri_window_buttons.so
systemctl --user status waybar.service --no-pager
```

If Waybar cannot load the plugin after an ABI or Fedora upgrade, inspect its
journal and rebuild through the role only when necessary.
