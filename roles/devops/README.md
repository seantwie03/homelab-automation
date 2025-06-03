Role Name
=========

Install DevOps tools

- Terraform


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
- name: Install DevOps Tools
  hosts: desktop
  become: true
  roles:
    - role: devops
```

License
-------

MIT

