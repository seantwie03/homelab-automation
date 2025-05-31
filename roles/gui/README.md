Role Name
=========

Install graphical software packages

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
- name: Install graphical software packages
  hosts: desktop
  become: true
  roles:
    - role: gui
```

License
-------

MIT

