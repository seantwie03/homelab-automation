# imgman install prototype

The hand-run prototype from Phase 2, kept as a reference while writing
`imgman`. Delete this directory with `imgman-plan.md`.

```sh
immutable/migration/imgman-prototype/install.sh   # about 6.5 minutes
immutable/migration/imgman-prototype/boot.sh      # SPICE=1 adds a SPICE socket
immutable/migration/imgman-prototype/vm.sh systemctl is-system-running --wait
```

Disks, logs, and the run directory are under `~/.cache/homelab-images/prototype/`.
