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

Handles auto-login on tty1 and launching the Wayland kiosk session. Uses
`{{ user }}` — the same variable all other roles use — so no new variable names
are needed. Override `user` at the role level when auto-login should target a
different account than the play-level `user`.

### `defaults/main.yml`

```yaml
---
user: sean
```

### Tasks

**1. agetty auto-login drop-in directory exists**
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
ExecStart=-/sbin/agetty --autologin {{ user }} --noclear %I $TERM
```

Follow the daemon_reload convention from CLAUDE.md: run `daemon_reload`
(with `changed_when: false`) after placing the drop-in.

`getty@tty1.service` is already enabled by default — no explicit enable task
needed unless the host has it disabled.

---

## New Role: `roles/apps/retrogaming`

Handles Flatpak setup, ES-DE, RetroArch, symlinks, config files, and
controller driver. Uses `{{ user }}` like all other roles. Override at the
role level on playbooks where the gaming user differs from the admin user.

### `meta/main.yml`

```yaml
---
dependencies:
  - role: flatpak
```

Flatpak and the Flathub remote are set up system-wide by the `flatpak` runtime
role. The `retrogaming` role declares it as a dependency so it runs
automatically — no manual Flathub task needed here.

### `defaults/main.yml`

```yaml
---
user: sean
emulation_roms_path: /home/{{ user }}/ROMs
emulation_bios_path: /home/{{ user }}/BIOS
emulation_saves_path: /home/{{ user }}/saves
```

The default paths are sensible for a desktop install where ROMs live in the
user's home directory. Playbooks with NAS-backed storage override them at the
role level.

### Tasks

**1. gaming user exists and is in the games group**
```yaml
- name: "{{ user }} user exists"
  ansible.builtin.user:
    name: "{{ user }}"
    shell: /bin/bash
    create_home: true
    state: present

- name: "{{ user }} is in the games group"
  ansible.builtin.user:
    name: "{{ user }}"
    groups: games
    append: true
```

User creation is task 1 so all subsequent tasks that write into the home
directory can rely on it unconditionally.

Fedora ships a `games` group by default — no group creation needed. Membership
grants access to `/srv/tier2/emulation/` once the bootstrap step below is
done. `sean` also needs to be in the `games` group; add that in
`odroidh3plus.yml` as a play-level task or extend the core role for that host.

**One-time bootstrap — run before first ansible-pull:**
 ```bash
 chgrp -R games /srv/tier2/emulation
 chmod -R g+rwX,o+rX /srv/tier2/emulation
 find /srv/tier2/emulation -type d -exec chmod g+s {} \;
 ```
 Sets group ownership to `games`, makes directories setgid (new content
 inherits the group), and makes everything group-writable and world-readable.
 The setgid bit on directories ensures this is a one-time operation — all
 future content inherits `games` ownership automatically.

**2. cage is installed**
```yaml
- name: cage is installed
  ansible.builtin.package:
    name: cage
    state: present
```
`cage` is in the Fedora default repos — no extra repo needed.

**3. session launch via `.bash_profile`**

```yaml
- name: cage session is configured in .bash_profile
  ansible.builtin.blockinfile:
    path: /home/{{ user }}/.bash_profile
    owner: "{{ user }}"
    group: "{{ user }}"
    mode: 0644
    marker: "# {mark} ANSIBLE MANAGED BLOCK: retrogaming autostart"
    block: |
      if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
          exec cage -- flatpak run org.es_de.ESDE
      fi
```

`blockinfile` inserts only the marked block, leaving any existing `.bash_profile`
content intact. Safe for desktop25 where `sean` may already have a
`.bash_profile` with legitimate content. Idempotent — subsequent runs update
the block in place rather than replacing the file.

`tty` asks the kernel what terminal the process is attached to — it does not
depend on PAM or logind having set `XDG_VTNR` in the environment, making it
more reliable under agetty autologin. `exec` replaces the bash process with
cage rather than forking a child, so when cage exits the session ends cleanly
instead of dropping to a bash prompt.

**4. ES-DE is installed**
```yaml
- name: es-de is installed
  community.general.flatpak:
    name: org.es_de.ESDE
    state: present
    method: system
```
> **Verify:** Confirm Flatpak ID is `org.es_de.ESDE` at https://flathub.org

**5. RetroArch is installed**
```yaml
- name: retroarch is installed
  community.general.flatpak:
    name: org.libretro.RetroArch
    state: present
    method: system
```

**6. RetroArch cores are downloaded**

RetroArch's built-in core downloader is the standard mechanism. However, for
Ansible idempotency, use `ansible.builtin.command` to download cores via the
RetroArch CLI if they are not already present. Cores live at:
`/home/{{ user }}/.var/app/org.libretro.RetroArch/config/retroarch/cores/`

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

**7. Emulation directories exist**

```yaml
- name: emulation directories exist
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
  loop:
    - "{{ emulation_roms_path }}"
    - "{{ emulation_bios_path }}"
    - "{{ emulation_saves_path }}"
    - "{{ emulation_saves_path }}/states"
```

Ownership and permissions on emulation directories are a manual bootstrap
concern, not managed by this role. The role only ensures the directories
exist. The `saves/states` entry is included here because RetroArch writes
savestates to that subdirectory and will fail silently if it is absent.

Document the required layout in `roles/apps/retrogaming/README.md`:

```
## Prerequisites — emulation directory permissions

Before running this role on a host where emulation data lives outside the
user's home directory, the following must be done once manually:

    chgrp -R games /path/to/emulation
    chmod -R g+rwX,o+rX /path/to/emulation
    find /path/to/emulation -type d -exec chmod g+s {} \;

Required layout:
  emulation_roms_path   group: games, mode: 2775
  emulation_bios_path   group: games, mode: 2775
  emulation_saves_path  group: games, mode: 2775

The gaming user (retrogaming) must be a member of the games group —
handled by task 1. The setgid bit ensures new content inherits the
games group automatically.
```

**8. ES-DE data and config directories exist**
```yaml
- name: es-de directories exist
  ansible.builtin.file:
    path: /home/{{ user }}/{{ item }}
    state: directory
    owner: "{{ user }}"
    group: "{{ user }}"
    mode: 0755
  loop:
    - .local/share/ES-DE
    - .local/share/ES-DE/themes
    - .local/share/ES-DE/gamelists
    - .local/share/ES-DE/gamelists/atari2600
    - .local/share/ES-DE/gamelists/gb
    - .local/share/ES-DE/gamelists/gba
    - .local/share/ES-DE/gamelists/gbc
    - .local/share/ES-DE/gamelists/gamegear
    - .local/share/ES-DE/gamelists/genesis
    - .local/share/ES-DE/gamelists/n64
    - .local/share/ES-DE/gamelists/neogeo
    - .local/share/ES-DE/gamelists/nes
    - .local/share/ES-DE/gamelists/psx
    - .local/share/ES-DE/gamelists/sega32x
    - .local/share/ES-DE/gamelists/snes
    - .var/app/org.es_de.ESDE/config/ES-DE
    - .var/app/org.libretro.RetroArch/config/retroarch
```

Per-system gamelist subdirectories must exist before the symlink task (9)
attempts to place links inside them. The two `.var/app/...` entries create the
Flatpak config directories before the template tasks (11, 12, 13) write into
them — these directories are normally created by the apps on first run, but
since the user is new and the apps haven't run yet, Ansible must create them.

> **Note:** The per-system directory names in the gamelist loop must match
> ES-DE's internal system names, not RetroPie's. Verify before implementing
> (see Open Question 3).

**9. Gamelist symlinks**

The existing gamelists use relative `./images/...` paths which ES-DE resolves
relative to the ROM directory — these should work without modification.

ES-DE reads gamelists from `~/.local/share/ES-DE/gamelists/<system>/gamelist.xml`.
Symlink each system's gamelist into that location:

```yaml
- name: gamelist symlinks exist
  ansible.builtin.file:
    src: "{{ emulation_roms_path }}/{{ item }}/gamelist.xml"
    dest: /home/{{ user }}/.local/share/ES-DE/gamelists/{{ item }}/gamelist.xml
    state: link
    owner: "{{ user }}"
    group: "{{ user }}"
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

**10. Flatpak filesystem permission overrides**

Both Flatpaks are sandboxed and will not see emulation paths outside the home
directory without explicit overrides. With system-wide installs, overrides are
managed as files under `/var/lib/flatpak/overrides/` — one file per app,
owned by root. This is cleaner than `ansible.builtin.command` with
`changed_when: false` and is a proper declarative Ansible file task.

> **Note — global scope is intentional:** System-level overrides apply to
> all users on the machine. If `sean` ever runs ES-DE or RetroArch directly,
> they will also have access to `/srv/tier2/emulation/`. On a NAS where `sean`
> owns that data anyway, this is desirable. The override file lives in
> `/var/lib/flatpak/overrides/` (not in any user's home directory) to make
> its system-wide scope visible and explicit.

The override file format is INI. Template two files:

`/var/lib/flatpak/overrides/org.es_de.ESDE`:
```ini
[Context]
filesystems={{ emulation_roms_path }};{{ emulation_bios_path }};{{ emulation_saves_path }};
```

`/var/lib/flatpak/overrides/org.libretro.RetroArch`:
```ini
[Context]
filesystems={{ emulation_roms_path }};{{ emulation_bios_path }};{{ emulation_saves_path }};
```

```yaml
- name: es-de flatpak override is configured
  ansible.builtin.template:
    src: flatpak-override-esde.j2
    dest: /var/lib/flatpak/overrides/org.es_de.ESDE
    mode: 0644

- name: retroarch flatpak override is configured
  ansible.builtin.template:
    src: flatpak-override-retroarch.j2
    dest: /var/lib/flatpak/overrides/org.libretro.RetroArch
    mode: 0644
```

**11. ES-DE settings template**

Template to
`/home/{{ user }}/.var/app/org.es_de.ESDE/config/ES-DE/es_settings.xml`.

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

**12. RetroArch global config template**

Template to
`/home/{{ user }}/.var/app/org.libretro.RetroArch/config/retroarch/retroarch.cfg`.

Key settings:
```ini
rgui_show_start_screen = "false"
config_save_on_exit = "false"
system_directory = "{{ emulation_bios_path }}"
savefile_directory = "{{ emulation_saves_path }}"
savestate_directory = "{{ emulation_saves_path }}/states"
libretro_directory = "/home/{{ user }}/.var/app/org.libretro.RetroArch/config/retroarch/cores"
```

The per-system `retroarch.cfg` backups from rasnasretro only contained
`input_remapping_directory` pointing to RetroPie paths — not portable.
Start fresh; RetroArch's defaults are reasonable.

**13. PSX duplicate listing fix**

The PSX system in ES-DE should not show both `.bin` and `.cue` files as
separate entries. Investigate ES-DE's `custom_systems.xml` mechanism to remove
`.cue` and `.CUE` from the PSX extension list, mirroring the fix applied on
rasnasretro. Template the file to
`/home/{{ user }}/.var/app/org.es_de.ESDE/config/ES-DE/custom_systems.xml`.

**14. Xbox One wireless controller driver**

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

roles:
  - role: core
  - role: ansible_pull
  - role: btrfs
  - role: cli
  - role: karakeep
  - role: autologin          # new — override user for a different login account
    vars:
      user: retrogaming
  - role: retrogaming        # new — override user and paths for NAS storage
    vars:
      user: retrogaming
      emulation_roms_path: /srv/tier2/emulation/roms
      emulation_bios_path: /srv/tier2/emulation/BIOS
      emulation_saves_path: /srv/tier2/emulation/saves
```

### `desktop25.yml` — install for existing sean user, local ROMs

```yaml
roles:
  # ... existing roles ...
  - role: retrogaming        # new — user defaults to sean, paths default to ~/ROMs etc.
    vars:
      emulation_roms_path: /path/to/roms   # set as appropriate
```

### `desktop22.yml` — auto-login only, no retrogaming

```yaml
roles:
  # ... existing roles ...
  - role: autologin          # new — no vars: override needed, user defaults to sean
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

6. **Xbox controller driver** — Test whether the wireless dongle works without
   any extra package on Fedora 43's kernel before adding a driver role.

7. **sean in games group** — Add `sean` to the `games` group on odroidh3plus
   so he retains write access to `/srv/tier2/emulation/` after the bootstrap
   chgrp. This can be a task in `odroidh3plus.yml` pre_tasks or in the host's
   core role configuration.

8. **Image paths in gamelists** — Not all systems have an `images/` directory
   in `/srv/tier2/emulation/roms/<system>/`. Systems with missing images will
   show games without box art — acceptable, not a blocker.
