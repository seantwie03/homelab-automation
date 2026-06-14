# gui Role - Monitoring

## Printing And Discovery

```sh
systemctl is-active cups.service avahi-daemon.service
lpstat -r
lpstat -p
```

CUPS and Avahi should be active. An empty printer list is acceptable when no
printer has been configured. Inspect service journals for discovery, driver, or
queue failures:

```sh
journalctl -u cups.service -u avahi-daemon.service \
    -b -p warning --no-pager
```

## Bluetooth

```sh
systemctl status bluetooth.service --no-pager
bluetoothctl show
```

Bluetooth service state can depend on available hardware. A missing or blocked
adapter should be reported separately from a failed daemon.

## Graphical User Services And Autostart

Run these from the managed user's graphical session:

```sh
systemctl --user status wayscriber.service --no-pager
systemctl --user --failed --no-pager
find ~/.config/autostart -maxdepth 1 -type f -printf '%f\n' | sort
journalctl --user -b -p warning --no-pager
```

`wayscriber.service` should be enabled after installation. Review failed
generated XDG autostart units and repeated startup warnings, but do not require
every installed desktop application to remain running.

Zoom is intentionally absent while the temporary RPM-signature workaround is
active in this role.

