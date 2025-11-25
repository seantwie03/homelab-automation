# ODroid H3+ (v2)

This document outlines the storage architecture and backup strategy for the ODroid H3+ server, which is configured via Ansible as part of the homelab automation project.

## System Overview

The primary goal of this server is to provide reliable, centralized file storage and a robust backup destination for workstations and critical data.

**Operating System**: Almalinux 10.1+

Key Technologies:

-   btrfs
-   btrbk - Snapshot/rollback of user data
-   restic - Encrypted offsite backups

### Hardware

The [ODroid H3+](https://www.hardkernel.com/shop/odroid-h3-plus/) is a single-board computer with an x86-64 processor. It has an M.2 slot, two SATA ports, two 2.5GB ethernet ports, and can support up-to 64GB of DDR4. Typically you buy the board then put your own RAM and Storage.

SBC:  ODroid H3+    [ODroid H3+](https://www.hardkernel.com/shop/odroid-h3-plus/)
CPU:  Intel N6005   [Intel Pentium Silver N6005](https://www.intel.com/content/www/us/en/products/sku/212327/intel-pentium-silver-n6005-processor-4m-cache-up-to-3-30-ghz/specifications.html)
RAM:  16GB (2x 8GB) [DDR4 SODIMM](https://www.amazon.com/dp/B08ZRSQX93?psc=1&ref=ppx_yo2ov_dt_b_product_details)
M.2:  500GB NVMe    [WD_BLACK SN770](https://www.westerndigital.com/products/internal-drives/wd-black-sn770-nvme-ssd#WDS250G3X0E)
HDD:  8TB (2x 4TB)  [WD Red Plus](https://www.westerndigital.com/products/internal-drives/wd-red-plus-sata-3-5-hdd#WD10EFRX)
CASE: Type 1        [H3 Case Type 1](https://www.hardkernel.com/shop/odroid-h3-case-type-1/)

Purchased August 2023.

## Storage Architecture

The storage is split between the NVMe SSD for performance-sensitive tasks and the HDDs for bulk, redundant storage. All filesystems are BTRFS.

### NVMe SSD (500GB)

The NVMe drive is primarily used for the operating system and its associated data.

-   **OS:** AlmaLinux 10.1+ with a BTRFS root filesystem.
-   **Application State:** May also host application state or caches.

### HDD BTRFS RAID1 (4TB Usable)

The two 4TB HDDs are configured as a single BTRFS volume with a RAID1 (mirrored) profile.

-   **Redundancy:** All data written to this volume exists on both drives. This protects against a single drive failure with no downtime. BTRFS also provides data scrubbing and self-healing to protect against bit rot.
-   **Mount Point:** The volume is mounted at `/srv`.
-   **Usage:** This volume is the primary location for **all** user data, including Tier 1 (original) and Tier 2 (copy) data, as well as on-site backups and workstation backups.

## Data Tiers and Backup Strategy

All user data resides on the BTRFS RAID1 volume mounted at `/srv`. Data is categorized into two tiers, primarily determining its off-site backup policy.

### Directory Structure for Tiers

To facilitate clear backup policies, data is organized within `/srv` as follows:

```
/srv/
├── tier1/
│   ├── docs/                  # Original documents, important paperwork
│   ├── app_data/              # Application data from self-hosted services
│   └── workstation_backups/   # Backups of workstation user data
└── tier2/
    ├── dvd_backups/      # Copies of DVDs
    ├── photo_backups/    # Backups from Google Photos
    └── audible_backups/  # Backups from Audible
```

### Tier 1: Original Data (Backed Up Off-site)

This tier includes all original, irreplaceable data.

-   **Live Location:** `/srv/tier1/` (on the BTRFS RAID1 volume).
-   **Protection:**
    -   **RAID1 Redundancy:** Protected from single-drive failure.
    -   **Bit Rot Protection:** Automatic self-healing from data corruption.
    -   **On-site Snapshots:** Regular BTRFS snapshots of `/srv/tier1` (managed by `btrbk`) provide point-in-time recovery.
    -   **Off-site Backup:** A nightly `restic` job backs up the entire `/srv/tier1/` directory to a Backblaze B2 cloud bucket.

### Tier 2: Copy Data (On-site Only)

This tier includes data that is a copy of another source and can be re-acquired if lost.

-   **Live Location:** `/srv/tier2/` (on the BTRFS RAID1 volume).
-   **Protection:**
    -   **RAID1 Redundancy:** Protected from single-drive failure.
    -   **Bit Rot Protection:** Automatic self-healing from data corruption.
    -   **On-site Snapshots:** Regular BTRFS snapshots of `/srv/tier2` (managed by `btrbk`) provide point-in-time recovery.
    -   **Off-site Backup:** **No off-site backup** is performed for this tier to save costs.

### `restic` Off-site Backup Command Example

The `restic` command for off-site backups will specifically target Tier 1 data:

```bash
restic backup /srv/tier1/ --tag=tier1
```

## Workstation Backups

The server acts as a central backup destination for BTRFS-based workstations.

-   **Methodology:** Workstations use `btrbk` to send incremental BTRFS snapshots to the server over SSH. This is highly efficient, only transferring changed data.
-   **Storage Location:** Backups are received by the server and stored in `/srv/workstation_backups/`.
-   **Workstation Configuration:** On the workstations, `btrbk` is used to manage snapshots and backups of the `/home` subvolume.

