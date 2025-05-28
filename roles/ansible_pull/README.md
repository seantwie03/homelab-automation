Role Name - ansible_pull
=========

Configure job to recurrently run `ansible-pull`.

Requirements
------------

DNF, Become

This role configures a recurring job. The job runs `ansible-pull` to clone the playbook to /opt/homelab-ansible. The idea is at the end of the provisioning process the following command would be ran:

`ansible-pull --limit localhost --accept-host-key --directory /opt --url github.com/homelab $(hostname --short).yml`

Role Variables
--------------

`homelab_ansible_repo_url`: URL to remote repository.

`ansible_pull_path`: The path to the `ansible-pull` executable. Will be different depending on installation method.

Dependencies
------------

`ansible-pull` must be installed on the managed host

### Recommended Steps

Follow the steps below to install ansible-pull globally.

```sh
sudo dnf install python3-pip
sudo python3 -m pip install ansible
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
        homelab_ansible_repo_url: https://github.com/your_username/your_reponame
        ansible_pull_path: /usr/local/bin/ansible-pull
```

License
-------

MIT

