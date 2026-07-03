---
name: test-emacs-config
description: Test this repository's Emacs configuration in an isolated Podman container instead of running host Emacs directly. Use when validating dotfiles/emacs/init.el or dotfiles/emacs/early-init.el, checking Emacs Lisp values/keybindings/package loading, or running batch Emacs commands for this config.
---

# Test Emacs Config

Use `.agents/skills/test-emacs-config/scripts/emacs-container` for Emacs
validation in this repository.

The wrapper builds a small Fedora image with `emacs-nox` using the same Fedora
major version as the host from `/etc/os-release`. It mounts only
`dotfiles/emacs/early-init.el` and `dotfiles/emacs/init.el` into a disposable
container home, and keeps ELPA packages in the named Podman volume
`homelab-emacs-elpa`.

Run commands through the wrapper instead of host `emacs`:

```sh
.agents/skills/test-emacs-config/scripts/emacs-container --eval '(princ "ok\n")'
```

The wrapper already loads `early-init.el` and `init.el`. Pass only additional
batch arguments such as `--eval` or `--funcall`.

Use this for:

- verifying the config loads
- checking variable values and key bindings
- confirming packages installed by `use-package :ensure t` are available
- avoiding writes to `dotfiles/emacs/`

Do not use the wrapper to save edits to the config files. Edit tracked files in
the repository normally, then validate with the container.
