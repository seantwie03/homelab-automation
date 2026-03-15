---
# Retro Gaming on odroidh3plus — Implementation Plan

Add retro gaming capabilities to the ODroid H3+ NAS using a minimal stack:
`agetty (auto-login) → cage (Wayland kiosk compositor) → ES-DE (frontend) → RetroArch (emulator)`

No full desktop environment. NAS services are unaffected.

---

## Existing Assets on odroidh3plus

All emulation data is already in place — no migration needed.

| Asset | Path |
|---|---|
| ROMs | `/srv/tier2/emulation/roms/<system>/` |
| BIOS files | `/srv/tier2/emulation/BIOS/` |
| Save files | `/srv/tier2/emulation/saves/` |
| Gamelists (scraped metadata) | `/srv/tier2/emulation/roms/<system>/gamelist.xml` |
| Box art / images | `/srv/tier2/emulation/roms/<system>/images/` (present for some systems) |
| rasnasretro RetroArch config backup | `/srv/tier2/emulation/rasnasretro-backups/configs/` |

Systems in use: `atari2600`, `gb`, `gba`, `gbc`, `gamegear`, `genesis`, `n64`, `neogeo`, `nes`, `psx`, `sega32x`, `snes`

---

## New Role: `roles/system/autologin`

Handles auto-login on tty1 and launching the Wayland kiosk session for a
configurable user.

### `defaults/main.yml`

```yaml
---
autologin_user: sean
```

### Per-playbook overrides

```yaml
# odroidh3plus.yml — auto-login as the dedicated retrogaming user
vars:
  autologin_user: retrogaming

# desktop22.yml — auto-login as the normal user (physical security is fine)
vars:
  autologin_user: sean   # or omit entirely; the default covers it
```

### Tasks

**1. cage is installed**
```yaml
- name: cage is installed
  ansible.builtin.package:
    name: cage
    state: present
```
`cage` is in the Fedora default repos — no extra repo needed.

**2. agetty auto-login drop-in directory exists**
```yaml
- name: getty@tty1 drop-in directory exists
  ansible.builtin.file:
    path: /etc/systemd/system/getty@tty1.service.d
    state: directory
    mode: 0755
```

**3. agetty auto-login drop-in**

Template `/etc/systemd/system/getty@tty1.service.d/autologin.conf`:
```ini
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin {{ autologin_user }} --noclear %I $TERM
```

Follow the daemon_reload convention from CLAUDE.md: run `daemon_reload`
(with `changed_when: false`) after placing the drop-in.

`getty@tty1.service` is already enabled by default — no explicit enable task
needed unless the host has it disabled.

**4. Session launch via `.bash_profile`**

Template `/home/{{ autologin_user }}/.bash_profile`:
```bash
# Launch Wayland kiosk session on tty1 login
if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
    exec cage -- /usr/bin/flatpak run org.es_de.ESDE
fi
```

Use `ansible.builtin.template` with `owner: "{{ autologin_user }}"`,
`mode: 0644`.

> **Note:** `flatpak run` may need the full path or a wrapper script depending
> on how the PATH is set in the bare login shell under cage. If ES-DE fails to
> launch, add a wrapper script at
> `/home/{{ autologin_user }}/.local/bin/start-esde.sh` and call that instead.

---

## New Role: `roles/apps/retrogaming`

Handles Flatpak setup, ES-DE, RetroArch, symlinks, config files, and
controller driver for a configurable user and storage paths.

### `defaults/main.yml`

```yaml
---
retrogaming_user: sean
retrogaming_create_user: false
emulation_roms_path: "{{ ansible_env.HOME }}/ROMs"
emulation_bios_path: "{{ ansible_env.HOME }}/BIOS"
emulation_saves_path: "{{ ansible_env.HOME }}/saves"
```

`retrogaming_create_user: false` means the role assumes the user already
exists (correct for desktop25 where `sean` exists, or desktop22). Set to
`true` on odroidh3plus where a dedicated `retrogaming` account is needed.

The default paths are sensible for a desktop install where ROMs live in the
user's home directory. Playbooks with NAS-backed storage override them.

### Per-playbook overrides

```yaml
# odroidh3plus.yml — dedicated user, ROMs on NAS storage
vars:
  retrogaming_user: retrogaming
  retrogaming_create_user: true
  emulation_roms_path: /srv/tier2/emulation/roms
  emulation_bios_path: /srv/tier2/emulation/BIOS
  emulation_saves_path: /srv/tier2/emulation/saves

# desktop25.yml — install for existing sean user, ROMs wherever sean keeps them
vars:
  # retrogaming_user: sean  ← default already covers this, omit
  emulation_roms_path: /path/to/roms   # set as appropriate
```

### Tasks

**1. retrogaming user exists (conditional)**
```yaml
- name: retrogaming user exists
  ansible.builtin.user:
    name: "{{ retrogaming_user }}"
    shell: /bin/bash
    create_home: true
    state: present
  when: retrogaming_create_user
```

> **Note:** When `retrogaming_create_user: true`, also verify no UID conflict
> on odroidh3plus by running `getent passwd` before first apply.

**2. Flathub remote is enabled**

ES-DE and RetroArch are installed per-user as Flatpaks. Check how existing
hosts (e.g., desktop25) set up Flathub and follow the same pattern.

```yaml
- name: flathub remote is enabled for {{ retrogaming_user }}
  community.general.flatpak_remote:
    name: flathub
    state: present
    flatpakrepo_url: https://dl.flathub.org/repo/flathub.flatpakrepo
    method: user
  become: true
  become_user: "{{ retrogaming_user }}"
```

**3. ES-DE is installed**
```yaml
- name: es-de is installed
  community.general.flatpak:
    name: org.es_de.ESDE
    state: present
    method: user
  become: true
  become_user: "{{ retrogaming_user }}"
```
> **Verify:** Confirm Flatpak ID is `org.es_de.ESDE` at https://flathub.org

**4. RetroArch is installed**
```yaml
- name: retroarch is installed
  community.general.flatpak:
    name: org.libretro.RetroArch
    state: present
    method: user
  become: true
  become_user: "{{ retrogaming_user }}"
```

**5. RetroArch cores are downloaded**

RetroArch's built-in core downloader is the standard mechanism. However, for
Ansible idempotency, use `ansible.builtin.command` to download cores via the
RetroArch CLI if they are not already present. Cores live at:
`~/.var/app/org.libretro.RetroArch/config/retroarch/cores/`

Cores needed (one task per core or a loop):

| System | Core name |
|---|---|
| NES | `fceumm_libretro.so` |
| SNES | `snes9x_libretro.so` |
| GBA | `mgba_libretro.so` |
| GB / GBC | `gambatte_libretro.so` |
| Genesis / GameGear | `genesis_plus_gx_libretro.so` |
| PSX | `pcsx_rearmed_libretro.so` |
| N64 | `mupen64plus_next_libretro.so` |
| Atari 2600 | `stella2014_libretro.so` |
| NeoGeo / FBA | `fbneo_libretro.so` |
| Sega 32X | `picodrive_libretro.so` |

> **Alternative:** Download cores interactively via RetroArch's menu on first
> boot and skip automating this step. The cores directory will then persist.
> Ansible can enforce presence with `ansible.builtin.stat` + skip-if-exists
> logic. Decide based on how reproducible you need core installation to be.

**6. Emulation directories exist and are accessible**

```yaml
- name: emulation directories exist
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: "{{ retrogaming_user }}"
    group: "{{ retrogaming_user }}"
    recurse: false
  loop:
    - "{{ emulation_roms_path }}"
    - "{{ emulation_bios_path }}"
    - "{{ emulation_saves_path }}"
```
> **Note:** Do not recurse — the roms directory may contain thousands of files
> and a recursive chown on every ansible-pull run is expensive.

**7. ES-DE data directories exist**
```yaml
- name: es-de data directories exist
  ansible.builtin.file:
    path: /home/{{ retrogaming_user }}/{{ item }}
    state: directory
    owner: "{{ retrogaming_user }}"
    group: "{{ retrogaming_user }}"
    mode: 0755
  loop:
    - .local/share/ES-DE
    - .local/share/ES-DE/gamelists
    - .local/share/ES-DE/themes
```

**8. Gamelist symlinks**

The existing gamelists use relative `./images/...` paths which ES-DE resolves
relative to the ROM directory — these should work without modification.

ES-DE reads gamelists from `~/.local/share/ES-DE/gamelists/<system>/gamelist.xml`.
Symlink each system's gamelist into that location:

```yaml
- name: gamelist symlinks exist
  ansible.builtin.file:
    src: "{{ emulation_roms_path }}/{{ item }}/gamelist.xml"
    dest: /home/{{ retrogaming_user }}/.local/share/ES-DE/gamelists/{{ item }}/gamelist.xml
    state: link
    owner: "{{ retrogaming_user }}"
    group: "{{ retrogaming_user }}"
  loop:
    - atari2600
    - gb
    - gba
    - gbc
    - gamegear
    - genesis
    - n64
    - neogeo
    - nes
    - psx
    - sega32x
    - snes
```

> **Note:** ES-DE system names may differ from the directory names used by
> RetroPie. Verify against ES-DE's default `es_systems.xml` before writing
> this task. For example, RetroPie uses `sega32x`; ES-DE may use `32x`.
> Adjust the loop values and symlink destinations accordingly.
>
> **Note:** On desktop25 where `emulation_roms_path` defaults to `~/ROMs`,
> the gamelist symlink tasks will silently do nothing useful if ROMs aren't
> scraped yet. That is fine — idempotent no-ops.

**9. Flatpak filesystem permission overrides**

Both Flatpaks are sandboxed and will not see emulation paths outside the home
directory without explicit overrides. Add an Ansible task to grant access:

```yaml
- name: es-de has filesystem access to emulation paths
  ansible.builtin.command:
    cmd: flatpak override --user --filesystem={{ item }} org.es_de.ESDE
  become: true
  become_user: "{{ retrogaming_user }}"
  changed_when: false   # flatpak override is idempotent; mark unchanged
  loop:
    - "{{ emulation_roms_path }}"
    - "{{ emulation_bios_path }}"
    - "{{ emulation_saves_path }}"

# Repeat for org.libretro.RetroArch
```

**10. ES-DE settings template**

Template to
`/home/{{ retrogaming_user }}/.var/app/org.es_de.ESDE/config/ES-DE/es_settings.xml`.

Key settings to carry forward from rasnasretro:
- `ThemeSet` → `carbon` (or choose a new theme)
- `SaveGamelistsMode` → `on exit`
- `Scraper` → `ScreenScraper`
- `AudioDevice` → `HDMI`
- `TransitionStyle` → `fade`
- `ScreenSaverBehavior` → `dim`
- `ScreenSaverTime` → `300000` (5 minutes)

> **Note:** ES-DE's settings file format differs from RetroPie EmulationStation.
> Do not copy `es_settings.cfg` from the backup — create a fresh template
> using ES-DE's documented options.

**11. RetroArch global config template**

Template to
`/home/{{ retrogaming_user }}/.var/app/org.libretro.RetroArch/config/retroarch/retroarch.cfg`.

Key settings:
```ini
rgui_show_start_screen = "false"
config_save_on_exit = "false"
system_directory = "{{ emulation_bios_path }}"
savefile_directory = "{{ emulation_saves_path }}"
savestate_directory = "{{ emulation_saves_path }}/states"
libretro_directory = "/home/{{ retrogaming_user }}/.var/app/org.libretro.RetroArch/config/retroarch/cores"
```

The per-system `retroarch.cfg` backups from rasnasretro only contained
`input_remapping_directory` pointing to RetroPie paths — not portable.
Start fresh; RetroArch's defaults are reasonable.

**12. PSX duplicate listing fix**

The PSX system in ES-DE should not show both `.bin` and `.cue` files as
separate entries. Investigate ES-DE's `custom_systems.xml` mechanism to remove
`.cue` and `.CUE` from the PSX extension list, mirroring the fix applied on
rasnasretro. Template the file to
`/home/{{ retrogaming_user }}/.var/app/org.es_de.ESDE/config/ES-DE/custom_systems.xml`.

**13. Xbox One wireless controller driver**

rasnasretro used `xow` which is deprecated. On Fedora with a modern kernel,
use `xone` (or `xpadneo` for the wireless adapter).

```yaml
- name: xone copr is enabled
  community.general.copr:
    name: sentry/xone
    state: enabled

- name: xone is installed
  ansible.builtin.package:
    name:
      - xone
      - xone-dkms
    state: present
```

> **Verify:** Check which package provides wireless Xbox One dongle support on
> Fedora 43 before committing to xone vs xpadneo. The wired controller may
> work without any extra driver on a modern kernel.

---

## Playbook Changes

### `odroidh3plus.yml` — dedicated retrogaming user, NAS-backed storage

```yaml
vars:
  user: sean
  uid: 1000
  gid: 1000
  autologin_user: retrogaming
  retrogaming_user: retrogaming
  retrogaming_create_user: true
  emulation_roms_path: /srv/tier2/emulation/roms
  emulation_bios_path: /srv/tier2/emulation/BIOS
  emulation_saves_path: /srv/tier2/emulation/saves

roles:
  - role: core
  - role: ansible_pull
  - role: btrfs
  - role: cli
  - role: karakeep
  - role: autologin      # new
  - role: retrogaming    # new
```

### `desktop25.yml` — install for existing sean user, local ROMs

```yaml
vars:
  # autologin_user not set — do not add autologin role here
  # retrogaming_user defaults to sean
  emulation_roms_path: /path/to/roms   # set as appropriate

roles:
  # ... existing roles ...
  - role: retrogaming    # new, no autologin role
```

### `desktop22.yml` — auto-login only, no retrogaming

```yaml
vars:
  autologin_user: sean   # or omit; default covers it

roles:
  # ... existing roles ...
  - role: autologin      # new, no retrogaming role
```

> **Note:** The role short names (`autologin`, `retrogaming`) assume the
> playbook's `roles_path` resolves them correctly. Use full paths
> (`system/autologin`, `apps/retrogaming`) if needed — check how existing
> roles like `core` and `btrfs` are resolved in this repo.

---

## Open Questions / Things to Verify Before Implementing

1. **UID for `retrogaming` user** — Run `getent passwd` on odroidh3plus to
   confirm 1001 is available.

2. **ES-DE Flatpak ID** — Confirm `org.es_de.ESDE` at flathub.org before
   writing tasks.

3. **ES-DE system names** — Cross-reference ES-DE's built-in system list
   against the directory names in `/srv/tier2/emulation/roms/` to ensure
   gamelist symlink destinations are correct (especially `sega32x` vs `32x`
   and `neogeo`).

4. **ES-DE config file path under Flatpak** — The Flatpak sandbox puts config
   at `~/.var/app/org.es_de.ESDE/config/ES-DE/`. Confirm this before
   templating.

5. **RetroArch core download mechanism** — Decide whether to automate core
   installation via CLI or do it once interactively via the RetroArch menu.

6. **Flatpak filesystem permissions** — ES-DE and RetroArch Flatpaks need
   explicit `--filesystem` overrides to access `/srv/tier2/emulation/`. Grant
   these via `flatpak override`:
   ```
   flatpak override --user --filesystem=/srv/tier2/emulation org.es_de.ESDE
   flatpak override --user --filesystem=/srv/tier2/emulation org.libretro.RetroArch
   ```
   Add an Ansible task using `ansible.builtin.command` with `changed_when`
   logic, or manage via `~/.local/share/flatpak/overrides/` files directly.

7. **Xbox controller driver** — Test whether the wireless dongle works without
   any extra package on Fedora 43's kernel before adding a driver role.

8. **Image paths in gamelists** — Not all systems have an `images/` directory
   in `/srv/tier2/emulation/roms/<system>/`. Systems with missing images will
   show games without box art — acceptable, not a blocker.
