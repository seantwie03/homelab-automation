# desktop22 — Monitoring Runbook

Ordered checklist for periodic health checks. Each section links to the relevant role's `MONITORING.md` for full detail.

---

## 1. Timers — quick overview

```
systemctl list-timers --all
```

Scan the `LAST` column. Any timer that hasn't fired in longer than its cadence warrants investigation.

---

## 2. Persistent Services

```
systemctl is-active docker tailscaled systemd-resolved wpa_supplicant cups avahi-daemon libvirtd
```

All should return `active` except `libvirtd`, which is socket-activated and returns `inactive` when idle — that is normal.

---

## 3. User Services

```
systemctl --user list-units --type=service --state=running
```

Expected running: `dunst`, `waybar`, `wayscriber`, `niri`, `pipewire`, `wireplumber`, `1Password`.

---

## 4. ansible-pull

See [`roles/system/ansible_pull/MONITORING.md`](roles/system/ansible_pull/MONITORING.md).

---

## 5. dnf Automatic Updates

See [`roles/system/dnf/MONITORING.md`](roles/system/dnf/MONITORING.md).

---

## 6. btrfs and btrbk

See [`roles/system/btrfs/MONITORING.md`](roles/system/btrfs/MONITORING.md).

---

## 7. Snapper Snapshots

Snapper is not managed by a role in this repo but runs on this host.

```
snapper -c root list
```

Expected counts (`sudo snapper -c root get-config` for reference):

| Type | Setting | Expected |
|------|---------|----------|
| `number` (pre/post) | `NUMBER_LIMIT=20` | ≤ 20 |
| timeline hourly | `TIMELINE_LIMIT_HOURLY=5` | ≤ 5 |
| timeline daily | `TIMELINE_LIMIT_DAILY=7` | 7 |
| timeline weekly | `TIMELINE_LIMIT_WEEKLY=4` | 4 |
| timeline monthly | `TIMELINE_LIMIT_MONTHLY=1` | 1 |

**Stale number-type snapshots:** If `number`-type snapshots are frozen at the limit with old dates (indicating no new pre/post snapshots are being added), delete them by ID:

```
sudo snapper -c root delete <id1> <id2> ...
```

**Known issue:** Since ~2026-04-06, ansible-pull pre/post snapshots are created with `timeline` cleanup instead of `number`. The 20 `number`-type snapshots that existed prior to that date were manually deleted on 2026-04-20. If new `number`-type snapshots appear in the future, this issue has resolved itself.
