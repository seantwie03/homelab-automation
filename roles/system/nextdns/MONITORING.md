# nextdns Role - Monitoring

## Resolver State

```sh
systemctl is-active systemd-resolved
resolvectl status
readlink -f /etc/resolv.conf
```

Expected:

- `systemd-resolved` is active.
- `/etc/resolv.conf` resolves to `/run/systemd/resolve/stub-resolv.conf`.
- Global DNS servers and the search domain match the role defaults or host
  overrides.
- DNS-over-TLS is enabled for the NextDNS servers.

## Resolution

```sh
resolvectl query mirrors.fedoraproject.org
resolvectl query odroidh3plus
resolvectl query odroidh3plus.odh3p.3246.win
```

Public and configured search-domain names should resolve. Use `resolvectl`,
not deprecated commands such as `nslookup`, for resolver-path verification.

## DNS Readiness Unit

`dns-online.service` is a dependency-triggered oneshot and is not expected to
remain active when nothing needs it.

```sh
systemctl cat dns-online.service
systemctl show dns-online.service -p Result -p ExecMainStatus
journalctl -u dns-online.service -b --no-pager
```

Its most recent invocation should complete successfully. Repeated 60-second
timeouts indicate unavailable DNS-over-TLS, network failure, or a captive
portal. Read the role README before changing DNS for captive-portal access.

