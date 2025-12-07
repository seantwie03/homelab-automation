# BTRFS Ansible Role

This role configures automated maintenance and local snapshotting for BTRFS filesystems. It handles two primary responsibilities:

1.  **Periodic Maintenance:** Enables and configures the standard BTRFS maintenance jobs (scrub, balance, trim) provided by the `btrfs-progs` package.
2.  **Automated Snapshots:** Uses `btrbk` to create and prune snapshots of critical user-data subvolumes.

## 1. Automated BTRFS Maintenance

This role enables systemd timers that perform essential, low-priority maintenance tasks on all mounted BTRFS filesystems.

### Maintenance Tasks Explained

*   **Scrub (`btrfs-scrub.timer`):** A BTRFS scrub reads all data and metadata on the filesystem and verifies it against its checksums. This is the primary defense against "bit rot" (silent data corruption).
    *   On a single drive, it reports any corruption it finds.
    *   On a RAID1 volume, it not only reports corruption but also automatically repairs the bad block using the good copy from the other disk.
    *   This is configured to run **monthly**.

*   **Balance (`btrfs-balance.timer`):** Re-stripes data across the disks in the filesystem. This is useful for ensuring data is evenly distributed, especially after adding or removing devices, but is generally good practice to run periodically to consolidate metadata.
    *   This is configured to run **monthly**.

*   **TRIM (`btrfs-trim.timer`):** Informs SSDs which data blocks are no longer in use, allowing the drive's internal garbage collection to work more efficiently. This is crucial for maintaining SSD performance and longevity. This timer is used in place of the generic `fstrim.timer`.
    *   This is configured to run **monthly**.

### How to Inspect Maintenance Routines

To ensure these maintenance tasks are scheduled and have been running correctly, you can use the following commands:

1.  **Check the Timer Schedules:**
    See when each maintenance task is scheduled to run next.
    ```bash
    sudo systemctl list-timers 'btrfs-*.timer'
    ```

2.  **Review Service Logs:**
    Check the output from the last run of a specific service. For example, to see the results of the last BTRFS scrub:
    ```bash
    sudo journalctl -u btrfs-scrub.service
    sudo journalctl -u btrfs-balance.service
    sudo journalctl -u btrfs-trim.service
    ```

3.  **Check Scrub Status Directly:**
    To see the status of the last scrub on a specific filesystem:
    ```bash
    # Check status for the root filesystem
    sudo btrfs scrub status /

    # Check status for a different BTRFS mount, e.g., /srv
    sudo btrfs scrub status /srv
    ```

## 2. Automated Snapshots with `btrbk`

This role uses `btrbk`, a dedicated tool for managing BTRFS snapshots, to provide a robust, point-in-time recovery solution for user data. This is separate from any system-level snapshots that might be taken by other tools like `snapper`.

### Snapshot Configuration

The snapshot configuration is managed via the `btrbk_volumes` variable in Ansible. This variable is a list of dictionaries, where each dictionary defines a BTRFS filesystem (`volume`) to be snapshotted.

This structure allows for different snapshot policies and storage locations for different filesystems (e.g., the root filesystem vs. a dedicated data filesystem).

*   **Target Subvolumes:** By default, the role is configured to take snapshots of the `/home` subvolume on the root (`/`) filesystem.

*   **Snapshot Storage:** Snapshot storage directories are defined on a per-volume basis to ensure snapshots are stored on the same filesystem as their source.
    *   The default snapshot directory for the root filesystem is `./.btrbk_snapshots`.
    *   **Important:** These snapshot directories (e.g., `/.btrbk_snapshots`, `/srv/.btrbk_snapshots`) are created as **BTRFS subvolumes themselves**. This prevents their contents from being redundantly included when other tools snapshot their parent filesystem.

*   **Retention Policy:** The role implements a Grandfather-Father-Son (GFS) retention scheme, which is also defined on a per-volume basis. The default policy is `24h 7d 4w`:
    *   Keeps hourly snapshots for the last **24 hours**.
    *   Of those, it keeps one daily snapshot for the last **7 days**.
    *   Of those, it keeps one weekly snapshot for the last **4 weeks**.
    *   Older snapshots are automatically pruned.

*   **Timer Override:** The default `btrbk.timer` is configured to run daily. This role overrides it to run **hourly** to ensure the `24h` retention policy can be fulfilled.

### Example Multi-Volume Configuration

To configure snapshots for both the root filesystem and a separate `/srv` data filesystem, you would define the `btrbk_volumes` variable in your playbook as follows:

```yaml
# In your playbook's vars section:
btrbk_volumes:
  - volume: /
    snapshot_dir: /.btrbk_snapshots
    snapshot_preserve: 24h 7d 4w
    subvolumes:
      - home
  - volume: /srv
    snapshot_dir: /srv/.btrbk_snapshots
    snapshot_preserve: 7d 8w 12m
    subvolumes:
      - .  # The dot refers to the volume mounted at /srv itself
```

### How to Inspect Snapshot Routines

1.  **Check the Snapshot Timer:**
    Verify that the timer is running hourly.
    ```bash
    sudo systemctl status btrbk.timer
    ```

2.  **Review `btrbk` Service Logs:**
    See the detailed output from every `btrbk` execution, including which snapshots were created and which were pruned.
    ```bash
    sudo journalctl -u btrbk.service
    ```

3.  **Perform a Dry Run (Most useful command):**
    To see exactly what `btrbk` *would* do for all configured volumes, use the `dryrun` command. This is the best way to verify that your configuration is correct.
    ```bash
    sudo btrbk -c /etc/btrbk/btrbk.conf dryrun
    ```

4.  **List Managed Snapshots with `btrbk`:**
    To see a structured list of all snapshots currently managed by `btrbk`:
    ```bash
    sudo btrbk list
    ```

5.  **List Snapshot Subvolumes Directly:**
    To see the raw BTRFS subvolumes that have been created, you must check each configured snapshot directory:
    ```bash
    sudo btrfs subvolume list /.btrbk_snapshots
    sudo btrfs subvolume list /srv/.btrbk_snapshots
    ```

