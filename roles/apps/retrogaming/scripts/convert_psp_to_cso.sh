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

image="maxcso:latest"

if ! docker image inspect "$image" &>/dev/null; then
    echo "error: docker image '${image}' not found — build it first:" >&2
    echo "  docker build -t maxcso /tmp/maxcso" >&2
    exit 1
fi

for iso_file in "$roms_dir"/*.iso; do
    [ -e "$iso_file" ] || continue

    base="${iso_file%.iso}"
    cso_file="${base}.cso"

    if [ -f "$cso_file" ]; then
        echo "skipping: $(basename "$cso_file") already exists"
        continue
    fi

    echo "converting: $(basename "$iso_file")"
    docker run --rm \
        -v "${roms_dir}:/roms" \
        "$image" \
        --block=2048 \
        --threads=4 \
        --use-zopfli \
        --quiet \
        "/roms/$(basename "$iso_file")" -o "/roms/$(basename "$cso_file")"
    echo "created: $(basename "$cso_file")"
done

echo "done"
