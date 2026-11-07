# AI

Install AI development tools for the user specified in the `user` variable.

The role installs AI packages such as: Antigravity CLI, Antigravity ACP server (`agy_acp_server`), Codex, and Claude Code.

## Shared Agent Instructions

`dotfiles/agents/AGENTS.md` holds user-level instructions that apply to every project. The role symlinks it to the global instruction file of each agent:

| Agent       | Global instruction file |
|-------------|-------------------------|
| Claude Code | `~/.claude/CLAUDE.md`   |
| Codex       | `~/.codex/AGENTS.md`    |
| Antigravity | `~/.gemini/GEMINI.md`   |

Edit the repository file directly; each agent reads the change in its next session. The role sets `~/.claude` and `~/.gemini` to mode `0700` because they hold credentials.

The instructions tell agents to align Markdown and Org tables with `align-tables`, an Emacs Lisp script that the role installs to `~/bin/align-tables`. It aligns every table in the given files in place with Emacs in batch mode, so Emacs and the `markdown-mode` package from the Emacs configuration must be installed:

```sh
align-tables README.md notes.org
```

It exits with status 3 and prints `FILE:LINE: table is N characters wide (limit 109)` for each aligned table wider than 109 characters. Wide tables are still aligned and saved; status 3 is only a warning that you can ignore.

## Antigravity Settings

The role symlinks the `dotfiles/antigravity` directory in this repository to
`~/.config/antigravity`. This provides user-level permission allowlists for safe
read-only Linux and Git commands across all projects.

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
