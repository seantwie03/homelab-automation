#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "usage: $0 <emulation_base_directory>" >&2
    echo "  e.g. $0 /srv/tier2/emulation" >&2
    exit 1
fi

base_dir="$1"
roms_dir="${base_dir}/roms"
media_dir="${base_dir}/media"

if [ ! -d "$roms_dir" ]; then
    echo "error: roms directory '$roms_dir' does not exist" >&2
    exit 1
fi

output_file="${base_dir}/unscraped_roms.txt"
> "$output_file"

rom_extensions="zip|chd|7z|nes|sfc|smc|gba|gbc|gb|n64|z64|v64|iso|bin|cue|cso|pbp|nds|gg|md|smd|gen|32x|pce|lnx|a26"

for system_dir in "$roms_dir"/*/; do
    system=$(basename "$system_dir")
    gamelist="${system_dir}gamelist.xml"
    has_gamelist=false
    [ -f "$gamelist" ] && has_gamelist=true

    while IFS= read -r -d '' rom_file; do
        rom_name=$(basename "$rom_file")
        rom_base="${rom_name%.*}"

        # check gamelist.xml for any reference to this file
        in_gamelist=false
        if $has_gamelist; then
            grep -qF "$rom_name" "$gamelist" && in_gamelist=true
        fi

        # check media directory for any image matching this rom's base name
        has_media=false
        if [ -d "${media_dir}/${system}" ]; then
            result=$(find "${media_dir}/${system}" -name "${rom_base}.*" -print -quit 2>/dev/null)
            [ -n "$result" ] && has_media=true
        fi

        if ! $in_gamelist && ! $has_media; then
            echo "${system}/${rom_name}" >> "$output_file"
        fi
    done < <(find "$system_dir" -maxdepth 1 -regextype posix-extended -regex ".*\.(${rom_extensions})" -print0)
done

count=$(wc -l < "$output_file")
echo "found ${count} unscraped roms — results written to ${output_file}"
