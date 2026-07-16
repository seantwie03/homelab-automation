---
name: test-neovim-config
description: Test this repository's Neovim configuration in an isolated Podman container instead of running host Neovim directly. Use when validating files under dotfiles/nvim, checking Lua values or keybindings, verifying lazy.nvim plugin loading, or running headless Neovim commands for this config.
---

# Test Neovim Config

Use `.agents/skills/test-neovim-config/scripts/neovim-container` for Neovim
validation in this repository.

The wrapper builds a small Fedora image using the same Fedora major version as
the host. It mounts `dotfiles/nvim` read-only, copies it into a container-only
tmpfs for startup, mounts the skill directory read-only at
`/workspace/test-neovim-config`, and keeps plugins, Mason packages, and
Treesitter parsers in the named Podman volume `homelab-neovim-data`. The tmpfs
copy lets lazy.nvim maintain its lockfile without changing the tracked file.

Run headless commands through the wrapper instead of host `nvim`:

```sh
.agents/skills/test-neovim-config/scripts/neovim-container \
    '+lua print(vim.inspect(vim.opt.number:get()))'
```

The wrapper loads the repository configuration, runs the supplied Neovim
arguments, converts any recorded Neovim error into a nonzero process exit, and
then exits with `qa!`. Quote `+lua` and other Ex arguments so the shell passes
each one as a single argument.

Use the default cached run for normal validation:

```sh
.agents/skills/test-neovim-config/scripts/neovim-container \
    '+lua assert(vim.g.mapleader == " ")'
```

Use `--fresh` when changing lazy.nvim bootstrap behavior, plugin declarations,
or the lockfile. It uses disposable Neovim data instead of the cached volume:

```sh
.agents/skills/test-neovim-config/scripts/neovim-container --fresh \
    '+lua assert(require("lazy") ~= nil)'
```

Use `--rebuild-image` after changing
`.agents/skills/test-neovim-config/Containerfile`.

For keybinding checks, inspect a mapping with `vim.fn.maparg` and assert its
expected command, callback, or description:

```sh
.agents/skills/test-neovim-config/scripts/neovim-container \
    '+lua local m = vim.fn.maparg("<leader>x", "n", false, true); assert(m.desc == "Open scratch buffer", vim.inspect(m))'
```

## Custom action unit tests

Run the MiniTest unit tests stored with the Neovim configuration through the
container wrapper:

```sh
.agents/skills/test-neovim-config/scripts/neovim-container \
    '+luafile /root/.config/nvim/scripts/minitest.lua'
```

Use the wrapper for:

- verifying the config loads without errors
- checking options, globals, autocmds, and keybindings
- confirming lazy.nvim plugins load from the lockfile
- avoiding writes to `dotfiles/nvim`

Do not use the wrapper to save edits to configuration files. Edit tracked files
normally, then validate them with the container.
