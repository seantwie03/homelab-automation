# waybar Role - Monitoring

## User Service

Run these checks from the managed user's graphical session:

```sh
systemctl --user is-enabled waybar.service
systemctl --user status waybar.service --no-pager
systemctl --user cat waybar.service
pgrep -a waybar
```

The service should be enabled and Waybar should be running during a supported
Wayland session. Inspect the effective drop-in to confirm it uses the
role-managed launch script.

## Configuration And Logs

```sh
readlink -f ~/.config/waybar
journalctl --user -u waybar.service -b --no-pager
```

The configuration link should resolve into this repository. Investigate
repeated crashes, missing modules, invalid JSON or CSS, and plugin load errors.
One-time GTK warnings that do not affect operation should be reported as
noncritical.

When Niri is installed, also verify
`/usr/lib/waybar/libniri_window_buttons.so` through the Niri monitoring
instructions.

