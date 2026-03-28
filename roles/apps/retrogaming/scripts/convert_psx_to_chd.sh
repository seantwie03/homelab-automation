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

for zip_file in "$roms_dir"/*.zip; do
    [ -e "$zip_file" ] || continue

    base="${zip_file%.zip}"
    chd_file="${base}.chd"

    if [ -f "$chd_file" ]; then
        echo "skipping: $(basename "$chd_file") already exists"
        continue
    fi

    echo "processing: $(basename "$zip_file")"

    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    unzip -q "$zip_file" -d "$tmp_dir"

    cue_file=$(find "$tmp_dir" -maxdepth 1 -name "*.cue" | head -n 1)

    if [ -z "$cue_file" ]; then
        echo "warning: no .cue file found in $(basename "$zip_file"), skipping" >&2
        rm -rf "$tmp_dir"
        trap - EXIT
        continue
    fi

    chdman createcd -i "$cue_file" -o "$chd_file" 2>&1 | grep -v "^Compressing,"

    rm -rf "$tmp_dir"
    trap - EXIT

    echo "created: $(basename "$chd_file")"
done

echo "done"
