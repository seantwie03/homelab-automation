#!/usr/bin/env bash
# Download a video and open it in mpv.
# Files persist in /tmp (named by title + video ID) so multi-session watching works.
# Fedora's systemd-tmpfiles cleans them up after 10 days.
# Usage: vid-play.sh <url>
# Also handles vid-play:// protocol URLs from Chrome.

set -euo pipefail

RAW="${1:?Usage: vid-play.sh <url>}"

# Strip vid-play:// scheme prefix and URL-decode if invoked as a protocol handler.
if [[ "$RAW" == vid-play://* ]]; then
    encoded="${RAW#vid-play://}"
    encoded="${encoded//+/ }"
    URL=$(printf '%b' "${encoded//%/\\x}")
else
    URL="$RAW"
fi

# Get the video ID to build a stable filename and locate the file after download.
ID=$(yt-dlp --quiet --skip-download --print "%(id)s" "$URL")

# Download only if not already present.
# --restrict-filenames makes the title filesystem-safe (spaces -> underscores, etc.)
yt-dlp --quiet --no-overwrites --restrict-filenames \
    -o "/tmp/vid-play-%(title).40s-%(id)s.%(ext)s" "$URL"

# Find the file by ID (the title portion may vary due to --restrict-filenames sanitizing).
VIDEO=$(ls "/tmp/vid-play-"*"${ID}".* | grep -v '\.part$' | head -1)

mpv "$VIDEO"
