Role Name
=========

Install [1password CLI](https://developer.1password.com/docs/cli/get-started/). Install [1Password GUI](https://support.1password.com/install-linux/#fedora-or-red-hat-enterprise-linux) when on graphical systems.

Requirements
------------

DNF, Become


Role Variables
--------------

None

Dependencies
------------

None

Example Playbook
----------------

```yml
---
- name: Install 1Password
  hosts: desktop
  become: true
  roles:
    - role: onepassword
```

License
-------

MIT

