Role Name
=========

Install and configure kitty terminal.

Requirements
------------

DNF, Become, Font specified in kitty.conf


Role Variables
--------------

`kitty_user`: A user to add kitty configuration to.

Dependencies
------------

The font in the kitty.conf must be installed. This is usually done with the `nerd_fonts` module.

Example Playbook
----------------

```yml
---
- name: Install and Configure kitty terminal
  hosts: desktop
  become: true
  roles:
    - role: kitty
      vars:
        kitty_user: linda
    - role: kitty
      vars:
        kitty_user: lucy
```

License
-------

MIT

