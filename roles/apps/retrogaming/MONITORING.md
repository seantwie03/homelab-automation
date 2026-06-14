# retrogaming Role - Monitoring

## Kiosk Session

```sh
loginctl list-sessions
loginctl session-status
pgrep -a cage
pgrep -a ES-DE
```

On the retrogaming host, tty1 should automatically log in the configured user,
start Cage, and launch ES-DE. Inspect the user journal when the session exits
back to a shell:

```sh
journalctl -b _UID=$(id -u retrogaming) --no-pager
```

## Required Files And Data

Read the role variables for the configured ROM, BIOS, save, and media paths.

```sh
test -x /opt/esde_start.sh
ls -l /opt/ES-DE_*_x64.AppImage
namei -l /srv/tier2/emulation/roms
namei -l /srv/tier2/emulation/bios
namei -l /srv/tier2/emulation/saves
```

Use the actual configured paths. The retrogaming user must be able to traverse
and write where required, and directories should preserve the shared `games`
group model described in the README.

## Controllers And Graphics

```sh
lsmod | grep -E 'xone|xpad'
ls -l /dev/input/by-id
cat /sys/class/drm/card*-*/status
```

Confirm the configured `video_output` is connected and expected controllers
appear. After a kernel upgrade, missing controller modules or firmware are more
likely than an ES-DE configuration failure.

