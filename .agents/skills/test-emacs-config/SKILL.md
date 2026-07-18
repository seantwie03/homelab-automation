---
name: test-emacs-config
description: Test this repository's Emacs configuration in an isolated Podman container instead of running host Emacs directly. Use when validating dotfiles/emacs/init.el or dotfiles/emacs/early-init.el, checking Emacs Lisp values/keybindings/package loading, or running batch Emacs commands for this config.
---

# Test Emacs Config

Use `.agents/skills/test-emacs-config/scripts/emacs-container` for Emacs
validation in this repository.

The wrapper builds a small Fedora image with `emacs-nox` using the same Fedora
major version as the host from `/etc/os-release`. It mounts
`dotfiles/emacs/early-init.el` and `dotfiles/emacs/init.el` into a disposable
container home, mounts `dotfiles/emacs/tests` read-only at
`/workspace/emacs-tests`, and keeps ELPA packages in the named Podman volume
`homelab-emacs-elpa`. The container drops all Linux capabilities and enables
`no-new-privileges`.

Run commands through the wrapper instead of host `emacs`:

```sh
.agents/skills/test-emacs-config/scripts/emacs-container --eval '(princ "ok\n")'
```

The wrapper already loads `early-init.el` and `init.el`. Pass only additional
batch arguments such as `--eval` or `--funcall`.

The wrapper initializes package.el between `early-init.el` and `init.el`, which
matches the relevant part of normal Emacs startup and makes installed ELPA
packages available before `use-package` forms are evaluated.

Use the default cached run for normal validation:

```sh
.agents/skills/test-emacs-config/scripts/emacs-container --eval '(princ "ok\n")'
```

Use `--fresh` when changing package bootstrap behavior or when checking that a
new `use-package :ensure t` dependency can install into an empty ELPA directory:

```sh
.agents/skills/test-emacs-config/scripts/emacs-container --fresh --eval '(princ "ok\n")'
```

Use `--rebuild-image` after changing
`.agents/skills/test-emacs-config/Containerfile`.

## Custom function tests

Run the ERT tests for custom functions defined in `dotfiles/emacs/init.el`:

```sh
.agents/skills/test-emacs-config/scripts/emacs-container \
    --load /workspace/emacs-tests/init-test.el \
    --funcall ert-run-tests-batch-and-exit
```

These tests call the functions directly. Keep keymap assertions in
`check-evil-bindings.el` instead of testing bindings through ERT.

## Evil keybinding validation

When changing Evil, leader, localleader, Org, or which-key-related bindings,
run the dedicated keybinding test:

```sh
.agents/skills/test-emacs-config/scripts/emacs-container \
    --load /workspace/test-emacs-config/check-evil-bindings.el
```

This test verifies Evil state maps, `SPC` leader maps, Org `\` localleader maps,
selected Org motion bindings, and which-key discoverability metadata.

If a keybinding is intentionally added, removed, or changed, update both:

- `docs/editor-keybindings.org`
- `.agents/skills/test-emacs-config/check-evil-bindings.el`

Then rerun the keybinding test and the basic smoke test:

```sh
.agents/skills/test-emacs-config/scripts/emacs-container --eval '(princ "ok\n")'
```

Use this for:

- verifying the config loads
- checking variable values and key bindings
- confirming packages installed by `use-package :ensure t` are available
- avoiding writes to `dotfiles/emacs/`

Do not use the wrapper to save edits to the config files. Edit tracked files in
the repository normally, then validate with the container.
