# virtualbox Role - Monitoring

## Kernel Modules

```sh
uname -r
lsmod | grep -E '^vbox'
modinfo vboxdrv
```

`vboxdrv` must be available for the running kernel. After a kernel upgrade,
module build or signing failures are the primary concern.

```sh
systemctl status vboxdrv.service --no-pager
journalctl -b -p warning --no-pager | grep -i virtualbox
```

The exact helper unit can vary by VirtualBox packaging. If `vboxdrv.service`
does not exist, rely on module state and the package's setup command rather
than treating the missing unit as failure.

## User Access And Virtual Machines

```sh
id
VBoxManage list vms
VBoxManage list runningvms
VBoxManage list hostonlyifs
```

The managed user should belong to `vboxusers`. Registered but stopped virtual
machines are normal. Report inaccessible VM definitions, missing virtual disks,
broken host-only networks, and module errors.

