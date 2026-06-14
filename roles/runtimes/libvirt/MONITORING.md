# libvirt Role - Monitoring

## Fedora Service Model

Fedora can use modular, socket-activated libvirt daemons. An inactive
`libvirtd.service` alone is not a failure.

```sh
systemctl list-unit-files 'virt*.socket' 'virt*.service'
systemctl list-units 'virt*.socket' 'virt*.service' --all
virsh -c qemu:///system version
```

Expected:

- `virsh` connects successfully.
- The relevant QEMU sockets, commonly `virtqemud.socket`, are available.
- No required modular daemon is failed.

## Networks, Pools, And Guests

```sh
virsh -c qemu:///system net-list --all
virsh -c qemu:///system pool-list --all
virsh -c qemu:///system list --all
```

Report inactive resources only when they are expected to autostart or currently
serve a guest. Confirm storage pools point at valid paths and have sufficient
free space.

## Failures

```sh
systemctl --failed --no-pager | grep -E 'libvirt|virt'
journalctl -b -p warning --no-pager | grep -E 'libvirt|virtqemu|qemu'
```

Guest shutdowns and inactive sockets can be normal. Prioritize connection
failures, failed units, missing storage, permission errors, and repeated QEMU
crashes.

