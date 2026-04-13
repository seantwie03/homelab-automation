# Storage Enhancements

## 1. Convert tier1 and tier2 to BTRFS Subvolumes

Currently `/srv/tier1` and `/srv/tier2` are plain directories inside the `/srv` BTRFS volume.
Converting them to subvolumes allows btrbk to snapshot and expire them independently with
different retention policies.

### Step 1 — Stop all writes to /srv

```bash
systemctl stop btrbk.timer
systemctl stop nfs-server
systemctl stop karakeep
# stop any other services writing to /srv
```

### Step 2 — Migrate tier1

```bash
mv /srv/tier1 /srv/tier1_old
btrfs subvolume create /srv/tier1
cp -a --reflink=auto /srv/tier1_old/. /srv/tier1/
```

### Step 3 — Migrate tier2

```bash
mv /srv/tier2 /srv/tier2_old
btrfs subvolume create /srv/tier2
cp -a --reflink=auto /srv/tier2_old/. /srv/tier2/
```

### Step 4 — Verify

Spot-check that files are present and ownership/permissions look correct.

```bash
ls -la /srv/tier1/
ls -la /srv/tier2/
btrfs subvolume list /srv
```

### Step 5 — Delete old snapshots

The existing snapshots in `/srv/.btrbk_snapshots/` were taken of the old flat-directory
layout (`subvolume .`). Once btrbk is reconfigured for the new subvolumes it will no longer
manage these — they become orphaned. Delete them now to reclaim space.

```bash
for snap in /srv/.btrbk_snapshots/srv.*; do btrfs subvolume delete "$snap"; done
```

### Step 6 — Delete old directories

```bash
rm -rf /srv/tier1_old
rm -rf /srv/tier2_old
```

### Step 7 — Update btrbk config in odroidh3plus.yml

Replace the single `/srv` volume entry (which snapshots `.`) with two separate subvolume
entries. Use a longer retention for tier1 (irreplaceable) and shorter for tier2 (copy data).

```yaml
btrbk_volumes:
  - volume: /
    snapshot_dir: /.btrbk_snapshots
    snapshot_preserve: 4h 7d 2w
    subvolumes:
      - home
  - volume: /srv
    snapshot_dir: /srv/.btrbk_snapshots
    snapshot_preserve: 4h 7d 4w 2m
    subvolumes:
      - tier1
  - volume: /srv
    snapshot_dir: /srv/.btrbk_snapshots
    snapshot_preserve: 4h 7d 2w
    subvolumes:
      - tier2
```

### Step 8 — Restart services

```bash
systemctl start btrbk.timer
systemctl start nfs-server
systemctl start karakeep
# restart any other services stopped in Step 1
```

Run btrbk once manually to confirm the new snapshots are created correctly:

```bash
btrbk run --progress
```

## TODO

- **Implement restic off-site backup** — restic is not installed or configured. `/srv/tier1`
  has no off-site backup. Create a `restic` role with a systemd timer, Backblaze B2
  credentials stored in a secrets file, and a nightly `restic backup /srv/tier1` job.

- **Address disk capacity** — `/srv` is at 87.88% full. The emulation directory is the
  largest consumer at 878GB. Evaluate whether all ROM/media content needs to live on the
  RAID1 volume.

- **Configure workstation btrbk receive** — `/srv/tier2/backups` is empty and btrbk has no
  `receive` or SSH stanza configured. The workstation backup workflow described in
  `odroidh3plus02.md` is not functional.

- **Restrict btrfs-trim to NVMe only** — `BTRFS_TRIM_MOUNTPOINTS=auto` runs trim against
  `/srv` (spinning HDDs) which don't support TRIM. Set the mountpoint explicitly to `/`
  (NVMe only) in `/etc/sysconfig/btrfsmaintenance`.

- **Add btrbk failure alerting** — a silent btrbk failure would go unnoticed. Add a
  `systemd` `OnFailure=` directive to notify on failure.
