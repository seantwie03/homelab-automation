# Ansible Pull Job

Configure Systemd Timer to recurrently run `ansible-pull`. Also installs Homelab Management (`h`) script

This role configures a recurring job. The job runs `ansible-pull` to clone the playbook to `/opt/homelab-automation`.

The Systemd Service name is `ansible-pull`. It is hardcoded in several places.

## Role Variables

`ansible_pull_path`: The path to the `ansible-pull` executable. Will be different depending on installation method.

`homelab_ansible_repo_url`: URL to remote repository.

`homelab_ansible_repo_git`: SSH URL to remote repository.

`homelab_docs_dir`: Path to documentation used in `h` script for `documentation` subcommands

`playbook_path`: Do not change this. Default is: `/opt/homelab-automation`

`ansible_pip_version`: The minimum patch version of the `ansible` pip package to install (e.g. `13.3.0`). The role pins to the minor version using `~=`, so patch updates apply automatically on every run. To adopt a new minor version, bump the `X.Y` portion of this variable.

`ansible_lint_pip_version`: Same pinning behavior as `ansible_pip_version`, but for `ansible-lint`.

`dnf_automatic_reboot`: Controls whether the system reboots after dnf-automatic applies updates. Valid values: `never`, `when-needed`, `always`. Default: `never`.

## Ansible Version Management

This role manages the `ansible` and `ansible-lint` pip packages using a minor-version pin (`~=X.Y.0`). This means:

- Patch updates (e.g. `13.3.0` → `13.3.1`) are applied automatically on every ansible-pull run.
- Minor and major upgrades require a deliberate change to `ansible_pip_version` or `ansible_lint_pip_version` in `defaults/main.yml`.

## Automated System Updates (dnf-automatic)

This role also configures `dnf-automatic` to apply all package updates on a daily schedule. Key behaviors:

- Runs after `ansible-pull.service` to avoid conflicts.
- Randomized delay is disabled so the timer fires promptly.
- Sends a desktop notification via `notify-send` with the count of upgraded packages. On headless systems with no user session, the notification is silently skipped.
- Sends a persistent (critical) notification if a reboot is required.
- Reboot behavior is controlled by `dnf_automatic_reboot`.

## Dependencies

`ansible-pull` must be installed on the managed host before the first run.

### Bootstrap

```sh
sudo dnf install python3-pip
sudo python3 -m pip install ansible ansible-lint
```

Ansible is installed via `pip` instead of `dnf` because the Fedora-packaged `ansible` does not include `ansible-pull`. `pip` is run with `sudo` because `ansible-pull` must be available system-wide for the root-owned systemd timer. After the first successful run, this role takes over version management.

## Example Playbook

```yml
---
- name: Configure workstation
  hosts: localhost
  connection: local
  become: true
  roles:
    - role: ansible_pull
      vars:
        ansible_pull_path: /usr/local/bin/ansible-pull
        homelab_ansible_repo_url: https://github.com/your_username/your_reponame
        homelab_ansible_repo_git: git@github.com:your_username/your_reponame.git
        homelab_docs_dir: /srv/docs/areas/homelab
```

