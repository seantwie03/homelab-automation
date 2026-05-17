# AGENTS.md

This file provides guidance to Codex when working with code in this repository.

## Project Overview

This is an **ansible-pull** based homelab configuration management system. Rather than a central control node pushing configs, each managed host pulls this repository and applies its own playbook via a systemd timer. Targets Fedora/RHEL systems only.

## Common Commands

```sh
# Lint all YAML/Ansible files
ansible-lint

# Install required collections
ansible-galaxy collection install -r collections/requirements.yml

# Run a playbook manually against localhost (must be run as root)
sudo ansible-pull \
    --limit localhost \
    --directory /opt/homelab-automation \
    --url https://github.com/seantwie03/homelab-automation.git \
    $(hostname --short).yml

# Run local testing through the h management script
h a test

# Run local testing with an explicit playbook
h a test desktop25.yml
```

No build or test framework exists; this is declarative Ansible configuration.

## Architecture

**Playbooks** (`desktop22.yml`, `desktop25.yml`, `odroidh3plus.yml`) map hostnames to ordered lists of roles. The filename must match `hostname --short` for ansible-pull to select the correct playbook.

**Roles** in `roles/` are the unit of configuration. Each role handles one concern, such as `btrfs`, `docker`, or `niri`. Roles use `defaults/main.yml` for overridable variables and `vars/main.yml` for fixed variables. Complex roles split tasks into sub-files included from `tasks/main.yml`.

**Dotfiles** live in `dotfiles/` and are symlinked into the appropriate location by roles. This means editing `~/.config/nvim/init.lua` directly edits the repo file, so changes can be tested live and committed from `/opt/homelab-automation`. Roles create symlinks like this:

```yaml
- name: symlink nvim dotfiles directory
  ansible.builtin.file:
    src: "{{ dotfiles_path }}/nvim"
    dest: /home/{{ user }}/.config/nvim
    state: link
    follow: false
    owner: "{{ user }}"
    group: "{{ user }}"
```

**Collections used:** `ansible.posix`, `community.general`, `community.docker` pinned in `collections/requirements.yml`.

## YAML and Task Conventions

- YAML files begin with `---` and end with a blank line.
- Task names are **entirely lowercase** and written as a state description, not an action. Omit leading "Ensure".
  - Good: `btrbk is installed`
  - Bad: `Ensure btrbk is installed` or `Install btrbk`
- File modes use **unquoted octal**: `0755` not `'0755'` or `755`.
- **Do not quote strings** unless required. Quotes are required when the value starts with a Jinja2 variable (`"{{ var }}/path"`), starts with a YAML special character, or is a boolean/number that must be treated as a string.
  - Good: `state: present`, `dest: /home/{{ user }}/.config`
  - Bad: `state: "present"`, `dest: "/etc/foo"`
- Prefer **generic modules** (`package`, `service`) over distro-specific ones (`dnf`, `systemd`).

## Shell Script Conventions

- Indent with **4 spaces** in all `.sh` and `.sh.j2` files.
- Scripts that must run as root should check at the top: `if [ "$(id -u)" -ne 0 ]; then echo "this script must be run as root" >&2; exit 1; fi`

## Repository Signing Key Conventions

When adding a DNF/YUM repository that uses a remote RPM signing key:

- Check the upstream public key into the role under `files/`.
- Deploy it to `/etc/pki/rpm-gpg/RPM-GPG-KEY-<name>` with `ansible.builtin.copy`.
- Import it with `ansible.builtin.rpm_key` from the deployed local file, not from the upstream URL.
- Pin the full expected fingerprint in the `rpm_key` task.
- Configure `ansible.builtin.yum_repository.gpgkey` with a `file:///etc/pki/rpm-gpg/RPM-GPG-KEY-<name>` URL, not an `https://` URL.
- Keep `gpgcheck: true`; use `repo_gpgcheck: true` when the upstream repository supports signed metadata.
- Update the role README with signing key rotation instructions: fetch command, fingerprint inspection command, and the task file/fingerprint value to update.

Reference implementation: `roles/apps/onepassword/tasks/main.yml`.

For direct remote RPM installs or release RPMs that own their repository files, such as Zoom or RPM Fusion, add retries around networked key imports and package installs:

```yaml
register: package_install
retries: 3
delay: 10
until: package_install is succeeded
```

## Systemd Service and Timer Conventions

**For timers:** After the package install task, place all configuration and override tasks first, then an unconditional `daemon_reload` task immediately before the enable/start task. This ensures systemd discovers both the new unit file and any overrides before the timer is enabled. The `daemon_reload` task must use `changed_when: false` to preserve idempotency. Override tasks must always use `notify` to trigger a handler that restarts the timer.

```yaml
- name: foo is installed
  ansible.builtin.package:
    name: foo
    state: present

# ... configuration and override tasks ...

- name: systemd daemon is reloaded
  ansible.builtin.systemd:
    daemon_reload: true
  changed_when: false

- name: foo.timer is enabled and started
  ansible.builtin.service:
    name: foo.timer
    enabled: true
    state: started
```

**For services:** No `daemon_reload` is needed; package scriptlets register the unit during install. A regular enable/start task after the package install is sufficient.

```yaml
- name: foo is installed
  ansible.builtin.package:
    name: foo
    state: present

- name: foo.service is enabled and started
  ansible.builtin.service:
    name: foo.service
    enabled: true
    state: started
```

Reference implementation: `roles/system/dnf/tasks/dnf_automatic.yml`.

## Role Documentation

When modifying a role, check whether `MONITORING.md` or `README.md` exists in the role directory. If either file exists, review it and update any content that the change makes inaccurate: commands, expected values, thresholds, timer schedules, or known issues.

## ansible-lint Configuration

`.ansible-lint.yml` skips:

- `var-naming[no-role-prefix]`: role variables do not need the role name prefix.
- `name[casing]`: task names are intentionally all-lowercase per project convention.
- `name[template]`: Jinja2 expressions are allowed in task names.

## Adding New Homelab Services

Services run on the ODroid H3+ (`192.168.0.149`). The naming convention is `SERVICE.odh3p.3246.win`.

**DNS:** No changes required. A wildcard rewrite in NextDNS (`odh3p.3246.win` to `192.168.0.149`) already covers all subdomains; a new service name resolves automatically. For full details on how DNS resolution works across all device types, see `dns-overview.md`.

**Short names:** On Linux and Windows, `SERVICE` without the domain suffix resolves to `SERVICE.odh3p.3246.win` via the `odh3p.3246.win` search domain configured by the `nextdns` role. Android requires the full name.

**HTTPS:** Certificates are issued via Let's Encrypt DNS-01 challenge against the `3246.win` domain. No ports need to be opened on the home router. The DNS-01 challenge validates domain ownership by writing a TXT record to `3246.win`; this works from inside the LAN with no inbound firewall changes.
