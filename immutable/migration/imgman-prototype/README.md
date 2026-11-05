# imgman install prototype

The hand-run prototype from Phase 2, kept as a reference while writing
`imgman`. Delete this directory with `imgman-plan.md`.

```sh
immutable/migration/imgman-prototype/install.sh [KICKSTART]   # about 7 minutes
HOST=x1carbon23 immutable/migration/imgman-prototype/boot.sh  # SPICE=1 adds a SPICE socket
immutable/migration/imgman-prototype/vm.sh systemctl is-system-running --wait
```

`install.sh` passes a throwaway LUKS passphrase, which a kickstart that does
not encrypt ignores. `boot.sh` boots with Secure Boot enforced and passes the
same passphrase as a `cryptsetup.passphrase` credential.

Disks, logs, and the run directory are under `~/.cache/homelab-images/prototype/`.
