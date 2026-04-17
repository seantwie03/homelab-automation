# Homelab Automation

Hello,

You've found my homelab-automation repository. It is pretty specific to my workflows, but I've made it open-source because there may be some concepts or ideas that could be useful for others.

## Automation Workflow

This automation workflow is built around [Ansible](https://ansible.readthedocs.io/) and [ansible-pull](https://docs.ansible.com/ansible/latest/cli/ansible-pull.html). In a typical Ansible setup, you install Ansible on a single **Control Node**, which then runs [Ansible Playbooks](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_intro.html) against **Managed Hosts** to configure them as desired.

However, this approach assumes that Managed Hosts are always online and accessible, which isn’t the case for most homelab workstations (desktops and laptop are often asleep, powered off, or on a different network). This is where ansible-pull excels.

With `ansible-pull`, you install Ansible on each Managed Host. Each host then pulls the latest version of a repository (like this one) and applies the configuration to itself. Combine this with a scheduled job and you can ensure that even intermittently available machines stay up to date with configuration changes.

## Getting Started

To get started, install the required packages and run `ansible-pull` as follows:

**Note:** The command below (along with many other things in this repository) has only been tested on Fedora and/or a recent version of an Enterprise Linux distribution (RHEL9+).

```sh
rm ~/.bashrc # Remove existing bashrc
sudo dnf install python3-libdnf5 python3-pip git wget hostname
sudo python3 -m pip install ansible-core ansible-lint
sudo git clone https://github.com/seantwie03/homelab-automation.git /opt/homelab-automation
sudo ansible-galaxy collection install -r /opt/homelab-automation/collections/requirements.yml
sudo ansible-pull \
    --limit localhost \
    --directory /opt/homelab-automation \
    --url https://github.com/seantwie03/homelab-automation.git \
    $(hostname --short).yml
```

Notice that the command above installs `ansible-core` via `pip` rather than `dnf` to get a newer version than what ships with Fedora. The commands above run with `sudo` because `ansible-pull` must be installed system-wide for the persistent systemd-timer that runs as root. Collections are installed with `sudo` so they land in `/root/.ansible/collections/` and are accessible when the timer runs as root.

After the first successful run, the `ansible_pull` role takes over version management. It keeps `ansible-core` and `ansible-lint` pinned to a minor version using pip's compatible release operator (`~=`), so patch updates apply automatically on every ansible-pull run. To adopt a new minor version, bump `ansible_pip_version` or `ansible_lint_pip_version` in `roles/system/ansible_pull/defaults/main.yml`.

The `ansible_pull` role also configures `dnf-automatic` to apply all system package updates daily. It runs after `ansible-pull` completes and sends a desktop notification with the number of upgraded packages. On headless systems with no active user session, the notification is silently skipped.

## WiFi Setup (Optional)

The steps above require internet connectivity. On a fresh system with a WiFi-only connection, set up WiFi manually before running anything else:

```sh
sudo dnf install iwlwifi-mvm-firmware NetworkManager-wifi wpa_supplicant
sudo systemctl enable --now wpa_supplicant
sudo systemctl restart NetworkManager
nmcli dev wifi connect "YourSSID" --ask
```

## Dotfiles

Since this repository is going to be cloned on every host (via ansible-pull) I add [my dotfiles](./dotfiles) in this repository. Then each role will symlink the relevant dotfiles subdirectory to the correct location on the system (usually ~/.config/...). The benefit to this approach is that I can see my changes right away. If I want to edit my neovim configuration, I can edit ~/.config/nvim/init.lua like normal. Any changes I make will be instantly applied like normal. Once I have tested the change I can cd to my /opt/homelab_automation and commit the changes. Then, those changes will be applied to every host in my homelab next time the ansible-pull service runs.

## The `h` Management Script

The `ansible_pull` role installs a script called `h` (for "homelab") that wraps common management tasks. It has two top-level commands, each with short aliases:

| Command | Description |
|---|---|
| `h a` / `h automation` | Homelab automation subcommands (default: `systemctl status ansible-pull.service`) |
| `h d` / `h documentation` | Homelab documentation subcommands |

**Automation subcommands (`h a <sub>`):**

| Subcommand | Description |
|---|---|
| `e` / `edit` | Open `$EDITOR` in `/opt/homelab-automation` |
| `c` / `commit` | `git add . && git commit -m <ISO timestamp> && git push` |
| `g` / `git [args]` | Run any git command in the automation dir (default: `git status`) |
| `l` / `logs` | `journalctl -u ansible-pull.service` |
| `r` / `run` | `sudo systemctl start ansible-pull.service` |
| `t` / `test [playbook]` | Run ansible-pull with `--force` (ignores dirty working dir); defaults to `$(hostname --short).yml` |
| `j` / `job [enable\|disable]` | Enable/disable `ansible-pull.timer`; default shows timer status |

**Documentation subcommands (`h d <sub>`):**

| Subcommand | Description |
|---|---|
| `e` / `edit` | Open `$EDITOR` in the homelab documentation directory |
| `i` / `inbox` | Open `inbox.md` in the homelab documentation directory |

## YAML Code Formatting

YAML files contain only `---` on the first line and an empty line at the end.

Try to name tasks as if starting with the word Ensure for example: 'Ensure btrbk is installed'. When doing this nearly every tasks starts with 'Ensure ...' which means the word Ensure is essentially line noise so omit it. Task names are entirely lowercase unless the task name contains a ENVIRONMENT_VARIABLE or other case-sensitive name where.

- Good: 'btrbk is installed'
- Bad: 'Ensure btrbk is installed'
- Good: 'btrbk.timer is enabled and started'
- Bad: 'Ensure btrbk.timer is enabled and started'
- Good: 'btrbk is configured'
- Bad: 'Template btrbk configuration file'
- Good: 'btrbk snapshot subvolume exists'
- Bad: 'Create btrbk snapshot subvolume'

When specifying file modes use octal notation without quotes.

- Good: 0755
- Bad: '0755'
- Bad: 755

Prefer generic modules like `package` and `service` instead of specific modules like `dnf` and `systemd`.
