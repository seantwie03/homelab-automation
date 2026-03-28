#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "usage: $0 <psx_roms_directory>" >&2
    exit 1
fi

roms_dir="$1"

if [ ! -d "$roms_dir" ]; then
    echo "error: directory '$roms_dir' does not exist" >&2
    exit 1
fi

declare -A disc_groups

# group disc files by their base name (everything before " (Disc N)")
while IFS= read -r -d '' disc_file; do
    filename=$(basename "$disc_file")
    base="${filename%.*}"
    group=$(echo "$base" | sed 's/ (Disc [0-9]\+)//')
    disc_groups["$group"]+="${filename}"$'\n'
done < <(find "$roms_dir" -maxdepth 1 -regextype posix-extended \
    -regex ".* \(Disc [0-9]+\)\.(chd|zip|bin|iso|cue)" -print0 | sort -z)

created=0
skipped=0

for group in "${!disc_groups[@]}"; do
    m3u_file="${roms_dir}/${group}.m3u"

    if [ -f "$m3u_file" ]; then
        echo "skipping: $(basename "$m3u_file") already exists"
        (( skipped++ )) || true
        continue
    fi

    # sort disc files and write to m3u
    echo "${disc_groups[$group]}" | grep -v '^$' | sort > "$m3u_file"

    disc_count=$(wc -l < "$m3u_file")
    echo "created: $(basename "$m3u_file") (${disc_count} discs)"
    (( created++ )) || true
done

echo "done — created ${created}, skipped ${skipped}"
