# Bluetooth

Installs Bluetooth support for bare window-manager environments that do not
provide a full desktop Bluetooth stack.

This role installs:

- `bluez`, which provides the system Bluetooth daemon and command-line tools.
- `dbus-devel` and `pkgconf-pkg-config`, which are needed to build Bluetui.
- `bluetui`, installed from Cargo into `/home/{{ user }}/bin`.

The role depends on `rust` so Cargo is available before Bluetui is installed.

## Bluetui

[Bluetui](https://github.com/pythops/bluetui) is a terminal UI for managing
Bluetooth devices on Linux.

Run it from the managed user's session:

```sh
bluetui
```

Useful default keys:

- `Tab` / `Shift+Tab`: move between sections.
- `j` / `k` or arrow keys: move through items.
- `s`: start or stop scanning.
- `o`: power the selected adapter on or off.
- `p`: toggle adapter pairing.
- `d`: toggle adapter discovery.
- `Space` / `Enter`: connect, disconnect, or pair, depending on the selected section.
- `t`: trust or untrust a paired device.
- `u`: unpair a paired device.
- `q` / `Ctrl+c`: quit.

Keybindings can be customized in `~/.config/bluetui/config.toml`.
