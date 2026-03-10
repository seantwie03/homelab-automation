# Instantly Add YouTube Videos to Jellyfin

## Overview

A two-part workflow: a small script on the desktop takes a YouTube URL, SSHes into
`odroidh3plus`, downloads the video via `yt-dlp`, generates a Jellyfin-compatible NFO
file using `jq`, triggers a Jellyfin library scan, and schedules automatic cleanup via
`systemd-tmpfiles`. The video appears in Jellyfin within seconds and disappears after 24
hours.

```
desktop25$ yt-get "https://youtube.com/watch?v=..."
  → SSH to odroidh3plus
    → yt-dlp downloads video + .info.json + thumbnail
    → jq generates .nfo from .info.json
    → curl triggers Jellyfin library refresh
    → video appears in Jellyfin
  → systemd-tmpfiles-clean.timer deletes files after 24h
```

---

## Components

| Component | Location | Purpose |
|---|---|---|
| `yt-get` | `~/bin/yt-get` on desktop25 | Thin wrapper — SSHes to server |
| `yt-add` | `/usr/local/bin/yt-add` on odroidh3plus | Downloads, generates NFO, triggers scan |
| `/srv/media/oneoff/` | odroidh3plus | Download target; Jellyfin watches this dir |
| `/etc/tmpfiles.d/oneoff.conf` | odroidh3plus | Deletes files older than 24h |
| Jellyfin "One-Off" library | Jellyfin | Points at `/srv/media/oneoff/` |
| Ansible role `yt_oneoff` | `roles/yt_oneoff/` | Provisions everything above on odroidh3plus |

---

## Server-Side Setup (odroidh3plus)

### 1. Packages

`yt-dlp` and `jq` must be installed. Both are in the Fedora repos.

```yaml
- name: yt-dlp and jq are installed
  ansible.builtin.package:
    name:
      - yt-dlp
      - jq
    state: present
```

Note: `yt-dlp` in the Fedora repos can lag behind upstream. If YouTube breaks
downloads, update `yt-dlp` manually with `pip install -U yt-dlp` or switch the package
source to pip. The Ansible role should document this.

### 2. Download Directory

```yaml
- name: /srv/media/oneoff directory exists
  ansible.builtin.file:
    path: /srv/media/oneoff
    state: directory
    mode: 0755
    owner: sean
    group: sean
```

Adjust the path to match wherever your Jellyfin media libraries live. `/srv` is already
a btrfs volume on this host per `odroidh3plus.yml`, so it is a natural fit.

### 3. Auto-Cleanup via systemd-tmpfiles

Fedora already runs `systemd-tmpfiles-clean.timer` daily. Drop a config file to register
the oneoff directory with it — no new timer or service needed.

```
# /etc/tmpfiles.d/oneoff.conf
e /srv/media/oneoff - - - 24h
```

The `e` type ("clean up") removes files and empty subdirectories whose modification time
is older than the specified age. All three files per video (`.mkv`, `.info.json`, `.jpg`)
share the same mtime set at download time, so they age and are cleaned up together.

```yaml
- name: tmpfiles rule for oneoff video cleanup exists
  ansible.builtin.copy:
    dest: /etc/tmpfiles.d/oneoff.conf
    content: "e /srv/media/oneoff - - - 24h\n"
    mode: 0644
```

To verify the rule without waiting: `systemd-tmpfiles --clean /etc/tmpfiles.d/oneoff.conf`

### 4. Jellyfin API Key

The `yt-add` script needs an API key to trigger Jellyfin library scans. Generate one in
Jellyfin under **Dashboard → API Keys**. Store it on the server in a file outside of
Ansible (same pattern as karakeep secrets):

```
/home/sean/.config/yt-add/jellyfin-api-key
```

```yaml
- name: yt-add config directory exists
  ansible.builtin.file:
    path: /home/sean/.config/yt-add
    state: directory
    mode: 0700
    owner: sean
    group: sean
```

The file itself is created manually — do not put the API key in this repo.

### 5. Jellyfin Library

In Jellyfin, create a new library manually:

- **Content type:** Movies
- **Name:** One-Off (or anything)
- **Folder:** `/srv/media/oneoff`
- **Metadata downloaders:** disable all external sources (no internet lookups needed;
  the NFO has everything)
- **Image fetchers:** disable all external sources

With all external metadata sources disabled, Jellyfin reads only local NFO files and
local thumbnails, which is exactly what `yt-add` provides.

---

## The `yt-add` Script (Primary Workflow)

This script runs on `odroidh3plus` as the `sean` user.

```bash
#!/usr/bin/env bash
# /usr/local/bin/yt-add
# Usage: yt-add <youtube-url>
#
# Downloads a YouTube video to /srv/media/oneoff, generates a Jellyfin-compatible
# NFO file, and triggers a Jellyfin library scan.

set -euo pipefail

URL="${1:?Usage: yt-add <youtube-url>}"

DOWNLOAD_DIR="/srv/media/oneoff"
JELLYFIN_URL="http://localhost:8096"
API_KEY_FILE="/home/sean/.config/yt-add/jellyfin-api-key"

if [[ ! -f "$API_KEY_FILE" ]]; then
    echo "ERROR: Jellyfin API key not found at $API_KEY_FILE" >&2
    exit 1
fi
JELLYFIN_API_KEY="$(cat "$API_KEY_FILE")"

# Download video, info JSON, and thumbnail.
# --quiet suppresses progress output so only --print output reaches stdout.
# after_move:filepath prints the final path of the video file after download.
VIDEO_FILE=$(yt-dlp \
    --quiet \
    --no-warnings \
    --write-info-json \
    --write-thumbnail \
    --convert-thumbnails jpg \
    --output "$DOWNLOAD_DIR/%(uploader)s - %(title)s [%(id)s].%(ext)s" \
    --print "after_move:filepath" \
    "$URL")

BASE="${VIDEO_FILE%.*}"
INFO_JSON="${BASE}.info.json"
NFO="${BASE}.nfo"

# Generate NFO from the .info.json using jq.
# @html escapes special XML characters (&, <, >) in text fields.
# upload_date format from yt-dlp is YYYYMMDD — reformat to YYYY-MM-DD for <premiered>.
jq -r '
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>",
  "<movie>",
  "  <title>" + (.title | @html) + "</title>",
  "  <plot>" + ((.description // "") | @html) + "</plot>",
  "  <year>" + (.upload_date[0:4] // "") + "</year>",
  "  <premiered>" + (
      (.upload_date[0:4] // "") + "-" +
      (.upload_date[4:6] // "") + "-" +
      (.upload_date[6:8] // "")
    ) + "</premiered>",
  "  <runtime>" + ((.duration // 0) / 60 | floor | tostring) + "</runtime>",
  "  <studio>" + ((.channel // .uploader // "") | @html) + "</studio>",
  "  <uniqueid type=\"youtube\" default=\"true\">" + (.id // "") + "</uniqueid>",
  "</movie>"
' "$INFO_JSON" > "$NFO"

# Trigger Jellyfin to scan the library so the video appears immediately.
curl -s -o /dev/null -X POST "${JELLYFIN_URL}/Library/Refresh" \
    -H "X-Emby-Token: ${JELLYFIN_API_KEY}"

echo "Done: $(basename "$VIDEO_FILE")"
```

```yaml
- name: yt-add script is installed
  ansible.builtin.copy:
    src: yt-add
    dest: /usr/local/bin/yt-add
    mode: 0755
    owner: root
    group: root
```

Place the script at `roles/yt_oneoff/files/yt-add`.

### NFO Field Mapping

| NFO tag | yt-dlp `.info.json` field | Notes |
|---|---|---|
| `<title>` | `.title` | XML-escaped |
| `<plot>` | `.description` | XML-escaped; falls back to empty string |
| `<year>` | `.upload_date[0:4]` | First 4 chars of `YYYYMMDD` |
| `<premiered>` | `.upload_date` reformatted | `YYYY-MM-DD` |
| `<runtime>` | `.duration / 60 \| floor` | Converted from seconds to minutes |
| `<studio>` | `.channel` or `.uploader` | XML-escaped |
| `<uniqueid>` | `.id` | YouTube video ID |

---

## The `yt-get` Script (Desktop)

A thin wrapper on `desktop25` that delegates everything to the server.

```bash
#!/usr/bin/env bash
# ~/bin/yt-get
# Usage: yt-get <youtube-url>

set -euo pipefail

URL="${1:?Usage: yt-get <youtube-url>}"

ssh odroidh3plus "yt-add '$URL'"
```

Install it via the existing `cli` role on `desktop25`, since that role already ensures
`~/bin` exists:

```yaml
- name: yt-get script is installed
  ansible.builtin.copy:
    src: yt-get
    dest: /home/{{ user }}/bin/yt-get
    mode: 0750
    owner: "{{ user }}"
    group: "{{ user }}"
```

Place the script at `roles/cli/files/yt-get` (or a dedicated role if preferred).

---

## Ansible Role: `yt_oneoff`

Create `roles/yt_oneoff/` for the server-side provisioning. Add it to `odroidh3plus.yml`.

**`roles/yt_oneoff/tasks/main.yml`:**

```yaml
---
- name: yt-dlp and jq are installed
  ansible.builtin.package:
    name:
      - yt-dlp
      - jq
    state: present

- name: /srv/media/oneoff directory exists
  ansible.builtin.file:
    path: /srv/media/oneoff
    state: directory
    mode: 0755
    owner: "{{ user }}"
    group: "{{ user }}"

- name: tmpfiles rule for oneoff video cleanup exists
  ansible.builtin.copy:
    dest: /etc/tmpfiles.d/oneoff.conf
    content: "e /srv/media/oneoff - - - 24h\n"
    mode: 0644

- name: yt-add config directory exists
  ansible.builtin.file:
    path: /home/{{ user }}/.config/yt-add
    state: directory
    mode: 0700
    owner: "{{ user }}"
    group: "{{ user }}"

- name: yt-add script is installed
  ansible.builtin.copy:
    src: yt-add
    dest: /usr/local/bin/yt-add
    mode: 0755
    owner: root
    group: root
```

**`odroidh3plus.yml`** — add the role:

```yaml
roles:
  - role: karakeep
  - role: yt_oneoff
```

---

## Backup NFO Method: jf-ytdlp-info-reader-plugin

If the `jq`-based NFO generation ever produces metadata that Jellyfin won't read (e.g.
due to a future NFO schema change), the `arabcoders/jf-ytdlp-info-reader-plugin` is the
backup. Instead of reading an NFO, it reads the `.info.json` directly inside Jellyfin.

### How It Works

The plugin registers itself as a metadata provider inside Jellyfin. When Jellyfin scans
a library item that has a `.info.json` alongside the video file, the plugin reads that
JSON and populates title, description, date, runtime, etc. — the same fields the `jq`
one-liner writes to the NFO, but without the conversion step.

Because `yt-add` already writes `--write-info-json`, switching to this plugin requires
no changes to the download script. Just install the plugin and reconfigure the Jellyfin
library metadata sources.

### Installation

1. Download the latest release `.zip` from
   [github.com/arabcoders/jf-ytdlp-info-reader-plugin/releases](https://github.com/arabcoders/jf-ytdlp-info-reader-plugin/releases)
2. Extract into Jellyfin's plugins directory:
   ```
   /var/lib/jellyfin/plugins/YTINFOReader/
   ```
3. Restart Jellyfin: `systemctl restart jellyfin`

### Library Configuration (with plugin active)

In the Jellyfin library settings for "One-Off":

- **Metadata downloaders (Movies):** move `YTINFOReader` to the top, disable all others
- **Image fetchers (Movies):** disable all external sources (thumbnail is local)

### Trade-offs vs jq Approach

| | `jq` NFO | jf-ytdlp-info-reader-plugin |
|---|---|---|
| External dependency | None beyond `jq` | Jellyfin plugin (must track Jellyfin API) |
| Brittleness | Low — NFO is stable XML | Medium — plugin must update with Jellyfin |
| Debugging | Inspect the `.nfo` file directly | Requires Jellyfin logs |
| Works if Jellyfin is offline | Yes (NFO is written to disk) | No (plugin reads at scan time) |

The `jq` approach is recommended. Keep the plugin as a known fallback.

---

## Usage

```bash
# On desktop25 — download a video and add it to Jellyfin immediately
yt-get "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

# Alternatively, SSH directly and run on the server
ssh odroidh3plus "yt-add 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'"

# Verify cleanup rules (dry run)
ssh odroidh3plus "systemd-tmpfiles --clean /etc/tmpfiles.d/oneoff.conf"

# Manually trigger cleanup right now (e.g. for testing)
ssh odroidh3plus "systemd-tmpfiles --clean --verbose /etc/tmpfiles.d/oneoff.conf"
```

---

## Manual Steps (Outside Ansible)

These must be done by hand — do not put secrets or UI configuration in this repo:

1. Generate a Jellyfin API key: **Dashboard → API Keys → +**
2. Write it to `odroidh3plus:/home/sean/.config/yt-add/jellyfin-api-key`
3. Create the Jellyfin "One-Off" library pointing at `/srv/media/oneoff/` with all
   external metadata sources disabled
4. Confirm the `yt-add` script path matches your Jellyfin's actual URL/port if it
   differs from `http://localhost:8096`
