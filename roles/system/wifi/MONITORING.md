# wifi Role - Monitoring

## NetworkManager State

```sh
systemctl is-active NetworkManager.service
nmcli general status
nmcli device status
nmcli connection show --active
```

Expected:

- NetworkManager is active.
- The Wi-Fi interface is present.
- An active Wi-Fi connection exists when the host is expected to use Wi-Fi.

A disconnected Wi-Fi interface is normal when Ethernet is the intended active
connection.

## Radio And Link

```sh
nmcli radio wifi
rfkill list wifi
nmcli device wifi list
```

Investigate disabled radios, hardware or software blocks, missing firmware, and
authentication failures separately.

## Supplicant Interpretation

```sh
systemctl status wpa_supplicant.service --no-pager
journalctl -u NetworkManager.service -u wpa_supplicant.service \
    -b -p warning --no-pager
```

NetworkManager may manage a supplicant instance without relying on the
standalone service process in the way older configurations did. Judge Wi-Fi
primarily by NetworkManager's device and connection state, not by
`wpa_supplicant.service` being active alone.

