Role Name
=========

Settings for Gnome Desktop Environment.

Requirements
------------

DNF, Become

`community.general.dconf` module


Role Variables
--------------

`dconf_users`: A list of users to apply dconf settings to.

Dependencies
------------

None

Example Playbook
----------------

```yml
---
- name: Configure Gnome
  hosts: desktop
  become: true
  roles:
    - role: gnome_settings
      vars:
        dconf_users:
          - linda
```

License
-------

MIT

