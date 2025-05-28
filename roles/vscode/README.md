Role Name
=========

Install VSCode and VSCode Insiders.

Requirements
------------

DNF, Become


Role Variables
--------------

None.

Dependencies
------------

None

Example Playbook
----------------

```yml
---
- name: Install VSCode
  hosts: desktop
  become: true
  roles:
    - role: vscode
```

License
-------

MIT

