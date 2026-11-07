# Ansible Pull

Runs `ansible-pull` daily from a systemd timer, so the host applies its
playbook from the repository's latest commit.

The image provides `ansible-pull` and `h`, the homelab management script. This
role configures what differs per host:

- `/etc/ansible-pull.conf`: the checkout's location, the repository URLs, the
  host's playbook, and the Ansible configuration it runs with.
  `ansible-pull.service` loads it as its environment, and `h` reads it, so the
  timer and `h test` run the same playbook from the same checkout.
- `ansible-pull.service` and `ansible-pull.timer`. The timer runs daily at
  03:00, persistent and with up to 10 minutes of random delay.
- The log directory, `/var/log/ansible-pull`, and its rotation.
- `ansible-pull-notify.sh`, which reports each run's result as a desktop
  notification.
- `git`'s `safe.directory` for the checkout, and group write access for
  `wheel`.

The service is condition-skipped in a VM, where `imgman test playbook` runs the
playbook from a copy of the working tree instead.

## Role Variables

| Variable                       | Default                                                | Meaning        |
|--------------------------------|--------------------------------------------------------|----------------|
| `homelab_ansible_repo_url`     | `https://github.com/seantwie03/homelab-automation`     | The            |
|                                |                                                        | repository's   |
|                                |                                                        | web page, for  |
|                                |                                                        | the unit's     |
|                                |                                                        | documentation  |
|                                |                                                        | link.          |
| `homelab_ansible_repo_git`     | `https://github.com/seantwie03/homelab-automation.git` | The URL        |
|                                |                                                        | `ansible-pull` |
|                                |                                                        | clones and     |
|                                |                                                        | pulls.         |
| `homelab_ansible_repo_git_ssh` | `git@github.com:seantwie03/homelab-automation.git`     | The URL        |
|                                |                                                        | `h commit`     |
|                                |                                                        | pushes to.     |
| `ansible_pull_playbook`        | `immutable/<hostname>.yml`                             | The playbook,  |
|                                |                                                        | relative to    |
|                                |                                                        | the checkout.  |
| `ansible_pull_config`          | `<checkout>/immutable/ansible.cfg`                     | The Ansible    |
|                                |                                                        | configuration  |
|                                |                                                        | the playbook   |
|                                |                                                        | runs with.     |

`playbook_path`, the checkout's location, is fixed at `/opt/homelab-automation`.

## Bootstrap

A new host has no checkout or settings yet, so run `ansible-pull` by hand once
as root. The playbook then installs this role, and the timer takes over:

```sh
sudo env ANSIBLE_CONFIG=/opt/homelab-automation/immutable/ansible.cfg \
    ansible-pull \
    --limit localhost \
    --directory /opt/homelab-automation \
    --url https://github.com/seantwie03/homelab-automation.git \
    immutable/$(hostname --short).yml
```

`ANSIBLE_CONFIG` names a file the clone creates. Ansible ignores an
`ANSIBLE_CONFIG` that names a missing file, so `ansible-pull` starts with its
defaults, and the `ansible-playbook` it runs after the clone inherits the
variable and reads the file.

## Dependencies

`core`, for the `is_graphical_system` fact.
