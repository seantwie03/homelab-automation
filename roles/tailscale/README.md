Role Name
=========

Install and enable [Tailscale](tailscale.com).

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
- name: Install tailscale
  hosts: server
  become: true
  roles:
    - role: tailscale
```

License
-------

MIT

