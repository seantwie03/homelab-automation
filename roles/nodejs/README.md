Role Name
=========

Install [Node.js](https://nodejs.org/en), [npm](https://www.npmjs.com/), and [pnpm](https://pnpm.io/).

Requirements
------------

DNF, Become


Role Variables
--------------

`node_version`: The node version to install. Example `22.x`

Dependencies
------------

`community.general.npm` module

Example Playbook
----------------

```yml
---
- name: Install NodeJS and package managers
  hosts: desktop
  become: true
  roles:
    - role: nodejs
      vars:
        node_version: 22.x
```

License
-------

MIT

