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

Zoom should be installed from the version-pinned official RPM:

```sh
rpm -q zoom
```

The role disables RPM signature verification only for this package because
RPM 6 rejects Zoom's current signing key. It also bypasses RPM's incorrect
Btrfs free-space result. The downloaded RPM is still verified against the
SHA-256 checksum pinned in `defaults/main.yml`.
