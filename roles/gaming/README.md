Role Name
=========

Install gaming launchers

- Steam
- [Heroic Games Launcher](https://heroicgameslauncher.com/)

Requirements
------------

DNF, Become


Role Variables
--------------

None.

Dependencies
------------

None.

Example Playbook
----------------

```yml
---
- name: Install gaming launchers
  hosts: desktop
  become: true
  roles:
    - role: gaming
```

License
-------

MIT

