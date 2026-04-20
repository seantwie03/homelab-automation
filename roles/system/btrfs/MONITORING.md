# btrfs Role — Monitoring

## btrbk Snapshots

List snapshots and their retention status:

```
sudo btrbk list snapshots
```

Verify counts match the `snapshot_preserve 24h 7d 4w` policy:

| Bucket | Expected |
|--------|----------|
| Hourly (last 24h) | up to 24 (fewer if machine was off) |
| Daily (last 7d) | 7 |
| Weekly (last 4w) | 4 |

All rows should show `STATUS: -` (retained). Any showing `ACTION: delete` will be pruned on the next btrbk run.

## btrfs Filesystem Usage

```
sudo btrfs filesystem usage /
```

| Metric | Threshold |
|--------|-----------|
| `Free (estimated)` | Alert if < 30 GiB |
| `Data` used % | Alert if > 90% — run a balance |
| `Metadata` used % | Alert if > 75% — urgent, can cause ENOSPC even when data appears free |
| `Device unallocated` | Alert if < 10 GiB — allocation headroom is nearly gone |

## Timers

| Timer | Cadence | What it does |
|-------|---------|-------------|
| `btrbk.timer` | Hourly | Creates and prunes `/home` snapshots |
| `btrfs-scrub.timer` | Monthly (1st) | Verifies data integrity |
| `btrfs-balance.timer` | Monthly (1st) | Repacks chunks, reclaims unallocated space |
| `btrfs-trim.timer` | Monthly (1st) | TRIM SSD |

A gap longer than ~35 days on the monthly timers means the machine was likely off on the 1st.
