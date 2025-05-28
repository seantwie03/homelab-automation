Role Name
=========

Install [NerdFonts](https://www.nerdfonts.com/) at system-level.

Requirements
------------

Become, Access to https://github.com/ryanoasis/nerd-fonts/releases

Role Variables
--------------

`nerd_fonts_version`: The tag version from https://github.com/ryanoasis/nerd-fonts/releases

```yml
nerd_fonts_version: v3.4.0
```

`fonts`: The font(s) to download and install

```yml
fonts:
  - Inconsolata
  - Iosevka
  - MPlus
  - UbuntuMono
  - ZedMono
```

Example Playbook
----------------

```yml
- name: Install NerdFonts
  hosts: desktops
  become: true
  roles:
    - role: nerd_fonts
      vars:
        fonts:
          - Iosevka
          - IosevkaTerm
          - MPlus
          - UbuntuMono
```

License
-------

MIT

