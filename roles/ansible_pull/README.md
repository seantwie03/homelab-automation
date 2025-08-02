Role Name - ansible_pull
=========

Configure job to recurrently run `ansible-pull`. Also installs Homelab Management (`h`) script

Requirements
------------

DNF, Become

This role configures a recurring job. The job runs `ansible-pull` to clone the playbook to /opt/homelab-automation. The idea is at the end of the provisioning process the following command would be ran to bootstrap the workstation.

`ansible-pull --limit localhost --accept-host-key --directory /opt/homelab-automation --url https://github.com/seantwie03/homelab-automation $(hostname --short).yml`

The systemd service name is `ansible-pull` it is hardcoded in several places.

Role Variables
--------------

`ansible_pull_path`: The path to the `ansible-pull` executable. Will be different depending on installation method.

`homelab_ansible_repo_url`: URL to remote repository.

`homelab_ansible_repo_git`: SSH URL to remote repository.

`homelab_docs_dir`: Path to documentation used in `h` script for `documentation` subcommands

`playbook_path`: Do not change this. Default is: `/opt/homelab-automation`

Dependencies
------------

`ansible-pull` must be installed on the managed host

### Recommended Steps

Follow the steps below to install ansible-pull globally.

```sh
sudo dnf install python3-pip
sudo python3 -m pip install ansible ansible-lint
```

Example Playbook
----------------

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

License
-------

MIT

