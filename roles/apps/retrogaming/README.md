# retrogaming

Installs and configures [ES-DE (frontend)](https://gitlab.com/es-de/emulationstation-de/-/blob/master/USERGUIDE.md) and [RetroArch (emulator)](https://buildbot.libretro.com/stable/) for a retro gaming station. Intended to run with `cage` as the Wayland kiosk compositor — no full desktop environment required.

## Prerequisites — emulation directory permissions

Before running this role on a host where emulation data lives outside the user's home directory, the following must be done once manually:

```
chgrp -R games /path/to/emulation
chmod -R g+rwX,o+rX /path/to/emulation
find /path/to/emulation -type d -exec chmod g+s {} \;
```

Required layout:

- `emulation_roms_path` — group: games, mode: 2775
- `emulation_bios_path` — group: games, mode: 2775
- `emulation_saves_path` — group: games, mode: 2775

The gaming user must be a member of the `games` group — handled by task 2. The setgid bit on directories ensures new content inherits the `games` group automatically, making this a one-time operation.

## Variables

| Variable | Default | Description |
|---|---|---|
| `user` | `sean` | User to configure. Created if absent, added to `games` group. |
| `emulation_roms_path` | `/home/{{ user }}/ROMs` | Path to ROM directories (one subdirectory per system). |
| `emulation_bios_path` | `/home/{{ user }}/BIOS` | Path to BIOS files. |
| `emulation_saves_path` | `/home/{{ user }}/saves` | Path to save files and states. |

