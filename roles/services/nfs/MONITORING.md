# nfs Role - Monitoring

## Services And Exports

```sh
systemctl is-active nfs-server.service rpcbind.service
sudo exportfs -v
cat /etc/exports
```

Expected:

- Both services are active.
- Every `nfs_exports` entry from the role configuration is active.
- Exported paths and client options match the generated configuration.

## Firewall And Listening Services

```sh
sudo firewall-cmd --list-services
rpcinfo -p localhost
```

The firewall should allow `nfs`, `rpc-bind`, and `mountd`. Required RPC
programs should be registered.

## Client Verification

From an allowed client:

```sh
showmount -e odroidh3plus
```

When practical, access an exported path through its client automount. Diagnose
failures as server availability, firewall, export matching, Unix permissions,
or stale NFS state rather than treating all mount errors alike.

```sh
journalctl -u nfs-server.service -u rpcbind.service \
    -b -p warning --no-pager
```

