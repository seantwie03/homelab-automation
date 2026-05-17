# Storage Enhancements

## 1. Convert tier1 and tier2 to BTRFS Subvolumes

Currently `/srv/tier1` and `/srv/tier2` are plain directories inside the `/srv` BTRFS volume.
Converting them to subvolumes allows btrbk to snapshot and expire them independently with
different retention policies.

### Step 1 — Stop all writes to /srv

```bash
systemctl stop btrbk.service btrbk.timer
systemctl stop nfs-server
systemctl stop smb nmb
docker compose -f /opt/karakeep/docker-compose.yml down

# confirm no known writers are still active
systemctl is-active btrbk.service nfs-server smb nmb
docker ps

# inspect any remaining open files before moving data
lsof +D /srv/tier1
lsof +D /srv/tier2
```

### Step 2 — Migrate tier1

```bash
stat -c '%U:%G %a %n' /srv/tier1
mv /srv/tier1 /srv/tier1_old
btrfs subvolume create /srv/tier1
cp -a --reflink=auto /srv/tier1_old/. /srv/tier1/
chown --reference=/srv/tier1_old /srv/tier1
chmod --reference=/srv/tier1_old /srv/tier1
restorecon -RFv /srv/tier1
```

### Step 3 — Migrate tier2

```bash
stat -c '%U:%G %a %n' /srv/tier2
mv /srv/tier2 /srv/tier2_old
btrfs subvolume create /srv/tier2
cp -a --reflink=auto /srv/tier2_old/. /srv/tier2/
chown --reference=/srv/tier2_old /srv/tier2
chmod --reference=/srv/tier2_old /srv/tier2
restorecon -RFv /srv/tier2
```

### Step 4 — Verify

Spot-check that files are present and ownership/permissions look correct.

```bash
ls -ld /srv/tier1 /srv/tier1_old
ls -ld /srv/tier2 /srv/tier2_old
ls -la /srv/tier1/
ls -la /srv/tier2/
getfacl -p /srv/tier1 /srv/tier2
ls -ldZ /srv/tier1 /srv/tier2
btrfs subvolume list /srv
```

### Step 5 — Update btrbk config in odroidh3plus.yml

Replace the single `/srv` volume entry (which snapshots `.`) with separate subvolume
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

After applying this change, verify btrbk accepts multiple `volume /srv` blocks that share the
same `snapshot_dir`. If btrbk does not accept this layout cleanly, update the btrfs role
template to support per-subvolume retention in a single `/srv` volume block instead of using
duplicate volume blocks.

### Step 6 — Apply and validate Ansible changes

Update the role documentation while changing the btrbk configuration:

- `roles/system/btrfs/README.md` should no longer show `/srv` using `subvolume .`.
- `roles/system/btrfs/MONITORING.md` should describe the separate `/home`, `/srv/tier1`,
  and `/srv/tier2` retention policies.

Then validate and apply the playbook:

```bash
ansible-lint
h a test odroidh3plus.yml
btrbk -c /etc/btrbk/btrbk.conf config print
btrbk -c /etc/btrbk/btrbk.conf dryrun
```

### Step 7 — Run btrbk manually

Run btrbk once manually to confirm the new snapshots are created correctly:

```bash
btrbk run --progress
btrbk list snapshots
btrfs subvolume list /srv/.btrbk_snapshots
```

### Step 8 — Restart services and smoke test

```bash
systemctl start btrbk.timer
systemctl start nfs-server
systemctl start smb nmb
docker compose -f /opt/karakeep/docker-compose.yml up -d

systemctl status btrbk.timer nfs-server smb nmb
docker ps
```

Smoke-test the expected consumers of `/srv` before deleting old data:

- NFS exports for `/srv/tier1` and `/srv/tier2`.
- Samba shares for `/srv/tier1` and `/srv/tier2`.
- Karakeep data under `/srv/tier1/app_data/karakeep`.
- Retrogaming data under `/srv/tier2/emulation`.

### Step 9 — Delete old snapshots

The existing snapshots in `/srv/.btrbk_snapshots/` were taken of the old flat-directory
layout (`subvolume .`). Once btrbk is reconfigured for the new subvolumes it will no longer
manage these — they become orphaned.

List and confirm the exact snapshot subvolumes before deleting anything:

```bash
btrbk list snapshots
btrfs subvolume list /srv/.btrbk_snapshots
for snap in /srv/.btrbk_snapshots/srv.*; do btrfs subvolume delete "$snap"; done
```

### Step 10 — Delete old directories

Only delete the old directories after the Ansible run, btrbk manual run, service restarts,
and smoke tests all pass.

```bash
rm -rf /srv/tier1_old
rm -rf /srv/tier2_old
```

## TODO

- **Implement restic off-site backup** — restic is not installed or configured. `/srv/tier1`
  has no off-site backup. Create a `restic` role with a systemd timer, Backblaze B2
  credentials stored in a secrets file, and a nightly `restic backup /srv/tier1` job.

- **Address disk capacity** — `/srv` is at 87.88% full. The emulation directory is the
  largest consumer at 878GB. Evaluate whether all ROM/media content needs to live on the
  RAID1 volume.

- **Configure workstation btrbk receive** — `/srv/tier2/backups` is empty and btrbk has no
  `receive` or SSH stanza configured. Define the intended receive path and SSH model in the
  current Ansible roles before relying on workstation backups.

- **Restrict btrfs-trim to NVMe only** — `BTRFS_TRIM_MOUNTPOINTS=auto` runs trim against
  `/srv` (spinning HDDs) which don't support TRIM. Set the mountpoint explicitly to `/`
  (NVMe only) in `/etc/sysconfig/btrfsmaintenance`.

- **Add btrbk failure alerting** — a silent btrbk failure would go unnoticed. Add a
  `systemd` `OnFailure=` directive to notify on failure.
