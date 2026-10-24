# Libvirt (KVM/QEMU)

Install Virtualization Tools included in `@virtualization` group.

Add user specified in `user` variable to libvirt group.

## start-latest-snapshot

Installs `/usr/local/bin/start-latest-snapshot`, which reverts libvirt domains
on `qemu:///system` to their newest snapshot (by creation time) and leaves them
running. **Changes made since that snapshot are discarded.**

```sh
# Show which snapshot each domain would be reverted to without changing anything
start-latest-snapshot --dry-run DOMAIN [DOMAIN ...]
start-latest-snapshot --dry-run --all

# Revert and start
start-latest-snapshot DOMAIN [DOMAIN ...]
start-latest-snapshot --all
```

The script is written in Python and uses the libvirt bindings from
`python3-libvirt`, which the role installs. Members of the `libvirt` group can
run it without sudo. The last line of
output summarizes which domains succeeded and failed. Exit status is `0` when
every domain succeeds, `1` when any domain fails, and `2` for usage errors.

