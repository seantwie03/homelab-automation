# dunst Role - Monitoring

## User Service

Run these checks from the managed user's graphical session:

```sh
systemctl --user is-enabled dunst.service
systemctl --user status dunst.service --no-pager
pgrep -a dunst
```

Dunst should be enabled and running when it provides the current session's
notification service.

## Notification Test And Logs

```sh
notify-send 'Dunst monitoring test' 'Notification delivery is working'
journalctl --user -u dunst.service -b --no-pager
```

Confirm the notification appears. Investigate D-Bus name conflicts when another
notification daemon is active or when a service file advertises a different
name. A known service-file naming warning is less important than failed
notification delivery.

```sh
readlink -f ~/.config/dunst
```

The configuration link should resolve into this repository.

