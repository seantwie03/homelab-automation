Role Name
=========

Install [uv](https://github.com/astral-sh/uv).

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
- name: Install python packages
  hosts: desktop
  become: true
  roles:
    - role: python
```

License
-------

MIT

