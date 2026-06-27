# gui Role - Monitoring

## Printing and Discovery

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

## Graphical User Services and Autostart

Zoom is intentionally absent while the temporary RPM-signature workaround is
active in this role.

