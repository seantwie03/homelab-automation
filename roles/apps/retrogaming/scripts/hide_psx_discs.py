#!/usr/bin/env python3
"""
Mark individual disc files as hidden in gamelist.xml for any PSX game
that has a corresponding .m3u playlist. Run after generate_psx_m3u.sh.

Usage: hide_psx_discs.sh <psx_roms_directory>
"""

import os
import sys
import glob
from xml.etree import ElementTree as ET

if len(sys.argv) != 2:
    print(f"usage: {sys.argv[0]} <psx_roms_directory>", file=sys.stderr)
    sys.exit(1)

roms_dir = sys.argv[1]

if not os.path.isdir(roms_dir):
    print(f"error: directory '{roms_dir}' does not exist", file=sys.stderr)
    sys.exit(1)

gamelist_path = os.path.join(roms_dir, "gamelist.xml")

if not os.path.isfile(gamelist_path):
    print(f"error: gamelist.xml not found in '{roms_dir}'", file=sys.stderr)
    sys.exit(1)

# collect all disc files referenced by .m3u playlists
disc_files = set()
for m3u_path in glob.glob(os.path.join(roms_dir, "*.m3u")):
    with open(m3u_path) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                disc_files.add(f"./{line}")

if not disc_files:
    print("no disc files found in any .m3u — nothing to do")
    sys.exit(0)

ET.register_namespace("", "")
tree = ET.parse(gamelist_path)
root = tree.getroot()

updated = 0
added = 0

for disc_path in sorted(disc_files):
    # find existing entry
    entry = None
    for game in root.findall("game"):
        path_el = game.find("path")
        if path_el is not None and path_el.text == disc_path:
            entry = game
            break

    if entry is not None:
        hidden_el = entry.find("hidden")
        if hidden_el is None:
            hidden_el = ET.SubElement(entry, "hidden")
        if hidden_el.text != "true":
            hidden_el.text = "true"
            updated += 1
    else:
        # create a minimal entry just to mark it hidden
        entry = ET.SubElement(root, "game")
        path_el = ET.SubElement(entry, "path")
        path_el.text = disc_path
        name_el = ET.SubElement(entry, "name")
        name_el.text = os.path.splitext(os.path.basename(disc_path))[0]
        hidden_el = ET.SubElement(entry, "hidden")
        hidden_el.text = "true"
        added += 1

ET.indent(tree, space="    ")
tree.write(gamelist_path, encoding="unicode", xml_declaration=True)

print(f"done — updated {updated} existing entries, added {added} new hidden entries")
