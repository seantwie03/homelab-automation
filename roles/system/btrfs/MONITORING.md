# btrfs Role - Monitoring

## Managed Filesystems And Snapshot Policy

Read `btrbk_volumes` in the host playbook and the role defaults. Confirm the
deployed configuration agrees:

```sh
btrbk -c /etc/btrbk/btrbk.conf config print
findmnt -t btrfs -o TARGET,SOURCE,FSTYPE,OPTIONS
```

The default configuration manages `/` and snapshots `/home`. Server hosts may
also manage filesystems such as `/srv`.

## btrbk Snapshots

```sh
btrbk -c /etc/btrbk/btrbk.conf list snapshots
```

Compare the snapshots with the configured volumes, subvolumes, and
`snapshot_preserve` policies in this repository. Allow for hosts being powered
off and for retention buckets to overlap. Investigate missing configured
subvolumes, unexpectedly stale snapshot history, command errors, or snapshots
that are not being pruned over time.

## Filesystem Usage

```sh
sudo btrfs filesystem usage /
```

Repeat for every distinct managed filesystem, such as `/srv`.

| Metric | Follow up when |
|---|---|
| `Free (estimated)` | Less than 30 GiB |
| `Data` used | Greater than 90% |
| `Metadata` used | Greater than 75% |
| `Device unallocated` | Less than 10 GiB |
| `Device missing` | Nonzero |

High allocated-chunk utilization is different from low filesystem free space.
Review both before recommending a balance.

## Device Errors And Scrub

```sh
sudo btrfs device stats /
sudo btrfs scrub status /
```

Repeat for every distinct managed filesystem.

Expected:

- All device error counters are zero.
- The latest scrub finished successfully with no errors.

Persistent device errors require investigation even if the latest scrub
completed successfully.

## Timers And Last Results

```sh
systemctl list-timers \
    btrbk.timer \
    btrfs-scrub.timer \
    btrfs-balance.timer \
    btrfs-trim.timer \
    --all
systemctl is-enabled fstrim.timer
```

| Timer | Expected cadence |
|---|---|
| `btrbk.timer` | Hourly |
| `btrfs-scrub.timer` | Monthly |
| `btrfs-balance.timer` | Monthly |
| `btrfs-trim.timer` | Monthly |

`fstrim.timer` should be disabled because `btrfs-trim.timer` replaces it.
Oneshot maintenance services are normally inactive between runs. Judge them by
their last result and journal:

```sh
systemctl show btrbk.service btrfs-scrub.service \
    btrfs-balance.service btrfs-trim.service \
    -p Id -p Result -p ExecMainStatus
journalctl -u btrbk.service -u btrfs-scrub.service \
    -u btrfs-balance.service -u btrfs-trim.service \
    --since '40 days ago' --no-pager
```

