# AI

Install AI development tools for the user specified in the `user` variable.

The role installs AI packages such as: Antigravity CLI, Codex, and Claude Code.

## Codex OpenRouter Profile

The regular `codex` command is left unchanged so it can continue using the
ChatGPT/free-tier authentication path.

The role symlinks `dotfiles/codex/openrouter.config.toml` in this repository
to `~/.codex/openrouter.config.toml`. Edit it directly to change the model or
reasoning effort — changes take effect immediately on the next `codex` run:

```sh
vim /opt/homelab-automation/dotfiles/codex/openrouter.config.toml
```

A convenience wrapper is also installed:

```sh
codex-openrouter
```

That wrapper runs:

```sh
codex --profile openrouter
```

After the role has run, create the OpenRouter API key file manually:

```sh
echo -n 'sk-or-...' > ~/.config/openrouter-api-key
chmod 0400 ~/.config/openrouter-api-key
```

The profile reads the API key from `/home/sean/.config/openrouter-api-key`
through Codex command-backed provider authentication. The key is not stored
in this repository.
