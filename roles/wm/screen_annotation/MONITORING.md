# screen_annotation Role - Monitoring

## Graphical User Services and Autostart

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

