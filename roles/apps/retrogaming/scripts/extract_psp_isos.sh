#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "usage: $0 <psp_roms_directory>" >&2
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

    if [ -f "${base}.iso" ] || [ -f "${base}.cso" ]; then
        echo "skipping: $(basename "$base") already extracted"
        continue
    fi

    echo "extracting: $(basename "$zip_file")"
    unzip -q "$zip_file" -d "$roms_dir"
    echo "extracted: $(basename "$zip_file")"
done

echo "done"
