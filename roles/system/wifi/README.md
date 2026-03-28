# WiFi

Install firmware and packages required for WiFi on Fedora, and enable `wpa_supplicant`.

## Hardware

desktop22 has a [TP-Link Archer TX55E](https://www.amazon.com/dp/B0B1NRGDQ4) PCIe WiFi card installed.

- **Chipset:** Intel AX210
- **WiFi Standard:** WiFi 6 (802.11ax), AX3000, Dual Band
- **Bluetooth:** 5.2
- **Security:** WPA3 / WPA2
- **Interface:** PCIe

## Connecting to a Network

After running this role, connect to a WiFi network with:

```sh
nmcli dev wifi connect "YourSSID" --ask
```
