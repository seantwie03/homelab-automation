---
name: query-running-emacs
description: Use to inspect or diagnose the user's currently running Emacs through emacsclient, especially while working on this repository's Emacs configuration in dotfiles/emacs/init.el. Supports read-only Elisp queries for live Emacs state, built-in and package documentation, function and variable availability, symbol source locations, buffer variables, modes, file watches, package state, key bindings, and diagnostics. Prefer this over web search for facts about the user's installed Emacs and loaded packages. Do not use for changing the live Emacs environment.
---

# Query Running Emacs

Start by asking the user to run `M-x server-start` in Emacs if an
`emacsclient` server is not already available.

Use this skill to query the user's live Emacs state while keeping the running
editor authoritative only as an inspection target. Query through
`.agents/skills/query-running-emacs/scripts/query-emacs-eval.sh`, but make
durable configuration changes only by editing `dotfiles/emacs/init.el` or
another tracked config file that it loads.

Prefer `emacsclient` over web search when the user asks about functions,
variables, key bindings, package APIs, or documentation that may depend on the
Emacs version and packages actually installed in the user's running session.

## Rules

- Only run read-only Elisp through
  `.agents/skills/query-running-emacs/scripts/query-emacs-eval.sh`.
- Do not call `emacsclient --eval` directly.
- Do not use live evaluation to set variables, enable or disable modes, install
  packages, mutate hooks, change keymaps, write files, or otherwise make
  one-off changes to the live Emacs environment.
- If a change is needed, edit `dotfiles/emacs/init.el` so it is applied on
  every Emacs start.
- If a live experiment seems useful, explain the exact temporary evaluation to
  the user and ask them to run it manually; do not run it through this skill.
- If the wrapper blocks a command that would be useful for a read-only query,
  notify the user so they can choose whether to add it to the wrapper.
- Treat `emacsclient` failures as setup information. If the socket is missing,
  ask the user to run `M-x server-start`. If permissions or sandboxing block the
  socket, rerun the same read-only query outside the sandbox with approval.

## Query Pattern

Prefer single-expression queries that return structured data:

```sh
.agents/skills/query-running-emacs/scripts/query-emacs-eval.sh '(list :emacs-version emacs-version :user-emacs-directory user-emacs-directory)'
```

For the selected buffer:

```sh
.agents/skills/query-running-emacs/scripts/query-emacs-eval.sh '(with-current-buffer (window-buffer (selected-window)) (list :buffer (buffer-name) :file buffer-file-name :major-mode major-mode))'
```

For optional variables, guard with `boundp`:

```sh
.agents/skills/query-running-emacs/scripts/query-emacs-eval.sh '(list :auto-revert-use-notify (if (boundp (quote auto-revert-use-notify)) auto-revert-use-notify :unbound))'
```

## Useful Read-Only Queries

Function documentation:

```sh
.agents/skills/query-running-emacs/scripts/query-emacs-eval.sh '(documentation (quote global-auto-revert-mode))'
```

Variable documentation:

```sh
.agents/skills/query-running-emacs/scripts/query-emacs-eval.sh '(documentation-property (quote auto-revert-interval) (quote variable-documentation))'
```

Symbol availability and source location:

```sh
.agents/skills/query-running-emacs/scripts/query-emacs-eval.sh '(list :fboundp (fboundp (quote global-auto-revert-mode)) :boundp (boundp (quote auto-revert-interval)) :function-file (symbol-file (quote global-auto-revert-mode) (quote defun)) :variable-file (symbol-file (quote auto-revert-interval) (quote defvar)))'
```

Command lookup by key:

```sh
.agents/skills/query-running-emacs/scripts/query-emacs-eval.sh '(list :key "C-x C-f" :command (key-binding (kbd "C-x C-f")) :doc (documentation (key-binding (kbd "C-x C-f"))))'
```

Auto-revert and file notification state:

```sh
.agents/skills/query-running-emacs/scripts/query-emacs-eval.sh '(list :global-auto-revert-mode global-auto-revert-mode :auto-revert-avoid-polling auto-revert-avoid-polling :auto-revert-use-notify (if (boundp (quote auto-revert-use-notify)) auto-revert-use-notify :unbound) :auto-revert-interval auto-revert-interval)'
```

Current buffer's auto-revert watch descriptor:

```sh
.agents/skills/query-running-emacs/scripts/query-emacs-eval.sh '(with-current-buffer (window-buffer (selected-window)) (list :buffer (buffer-name) :file buffer-file-name :watch (and (boundp (quote auto-revert-notify-watch-descriptor)) auto-revert-notify-watch-descriptor)))'
```

Current key binding:

```sh
.agents/skills/query-running-emacs/scripts/query-emacs-eval.sh '(key-binding (kbd "C-x C-f"))'
```

Mode and local variables in the selected buffer:

```sh
.agents/skills/query-running-emacs/scripts/query-emacs-eval.sh '(with-current-buffer (window-buffer (selected-window)) (list :buffer (buffer-name) :major-mode major-mode :minor-modes minor-mode-list :local-variables (buffer-local-variables)))'
```

Loaded feature or function availability:

```sh
.agents/skills/query-running-emacs/scripts/query-emacs-eval.sh '(list :feature-loaded (featurep (quote use-package)) :function-bound (fboundp (quote use-package)))'
```

## Reporting

Summarize what the query proves and what it does not prove. When the answer
depends on the selected frame, selected window, or selected buffer, say so
explicitly. If recommending a config change, point to `dotfiles/emacs/init.el`
as the place to make it persistent.
