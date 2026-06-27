# network_storage Role - Monitoring

## Expected Mounts

Read `nfs_mounts` and `bind_mounts` from the role defaults and host variables.
Then compare them with the deployed configuration:

```sh
findmnt --fstab
systemctl list-units --type=automount --all
systemctl list-units --type=mount --all
```

Every configured path should have a generated automount unit. Because these
mounts use `x-systemd.automount`, the corresponding mount unit may remain
inactive until the path is accessed.

## Trigger And Verify

For each configured NFS path:

```sh
ls /srv/tier1 >/dev/null
findmnt /srv/tier1
```

Use the actual configured paths. A successful access should activate the mount
without delaying boot when the server is unavailable.

For bind mounts, verify that the source and destination expose the same
filesystem content:

```sh
findmnt /home/sean/u
```

## Failures

```sh
systemctl --failed --type=mount --type=automount --no-pager
journalctl -b -u remote-fs.target -u local-fs.target --no-pager
```

For a failed generated unit, inspect its status and journal. Distinguish an
unreachable NFS server from DNS, permissions, stale file handles, and local
mount configuration errors.
