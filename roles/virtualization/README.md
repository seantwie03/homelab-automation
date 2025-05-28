Role Name
=========

Install Virtualization Tools included in '@virtualization' group and add users to libvirt group.

Requirements
------------

DNF, Become


Role Variables
--------------

`libvirt_users`: A list of users to add to the libvirt group.

Dependencies
------------

None

Example Playbook
----------------

```yml
---
- name: Install Virtualization Tools
  hosts: desktop
  become: true
  roles:
    - role: virtualization
      vars:
        libvirt_users:
          - linda
```

License
-------

MIT

