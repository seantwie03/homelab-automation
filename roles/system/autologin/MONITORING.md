# autologin Role - Monitoring

## Effective Getty Configuration

```sh
systemctl cat getty@tty1.service
systemctl status getty@tty1.service --no-pager
```

The effective unit should include the role-managed drop-in and pass
`--autologin` with the configured user.

## Session

```sh
loginctl list-sessions
loginctl user-status retrogaming
```

Use the role's configured user when it differs. After boot, tty1 should have a
local session for that user. The getty service may be inactive after handing
the terminal to the logged-in session, so inactivity alone is not a failure.

```sh
journalctl -b -u getty@tty1.service --no-pager
```

Investigate repeated login loops, a missing user, an invalid shell, or immediate
session termination. For retrogaming hosts, continue with that role's kiosk
session checks.

