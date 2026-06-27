# Bluetooth

```sh
systemctl status bluetooth.service --no-pager
bluetoothctl show
```

Bluetooth service state can depend on available hardware. A missing or blocked
adapter should be reported separately from a failed daemon.

