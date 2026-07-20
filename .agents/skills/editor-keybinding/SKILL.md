---
name: editor-keybinding
description: Plan, document, implement, and validate keybindings shared by this repository's Emacs and Neovim configurations. Use when the user asks what key should invoke an editor capability, wants to add or change a binding, wants consistent behavior across Emacs and Neovim, or wants to expand docs/editor-keybindings.org.
---

# Editor Keybinding

Use `docs/editor-keybindings.org` as the authoritative design and status
document.

## Plan The Binding

1. Research established bindings for the requested capability before proposing
   a key. Search current upstream sources and documentation for relevant native
   editor defaults and popular configurations such as Doom Emacs and LazyVim.
   Prefer official documentation and upstream repositories. Search other
   established configurations when they provide useful context.
2. Read `docs/editor-keybindings.org` in full enough to understand the existing
   prefix taxonomy, nearby commands, reserved keys, duplicates, and unimplemented
   plans. Inspect the relevant Emacs and Neovim config sections when collision or
   current behavior matters.
   Re-read files on every task; do not assume the configuration is unchanged.
   Use `query-running-emacs` for installed Emacs documentation when its server is
   available, and use the editor container skills for isolated API inspection.
3. Ask whether the binding targets Emacs, Neovim, or both unless the user already
   specified the scope. Gather missing behavior, mode, scope, project-root,
   fallback, picker, prefix, or persistence requirements.
4. Recommend a binding when asked, or when another key is materially more
   consistent with established conventions or this keymap. Explain the tradeoff
   concisely. Respect the user's decision without repeated pushback.
5. Prefer one memorable binding per capability. Do not introduce aliases or
   duplicate bindings unless the user explicitly wants them for an adoption
   period or discoverability experiment.
6. Distinguish semantic equivalence from identical implementation. Emacs and
   Neovim may use different providers while presenting the same user workflow.

## Update The Document

Before implementation, add the agreed design to the appropriate table in
`docs/editor-keybindings.org`, or create a clearly named table when no existing
category fits. Use these exact columns:

| Key | Mode | Emacs Provider | Emacs Function | Nvim Provider | Nvim Function |

Follow these conventions:

- Write key values and function or command names as plain text without Org `=`
  delimiters.
- Use one Neovim mode per row. Duplicate rows when a key applies in multiple
  modes.
- Use `builtin` for behavior shipped with the editor, the actual package or
  plugin name for external behavior, and `custom` for repository-defined code.
- During planning, record the provider and function that should implement the
  agreed behavior, even when it has not been wired yet.
- Use `N/I` when implementation is intentionally deferred or still unresolved.
- Use `N/A` only when the binding does not apply to that editor and will never
  be implemented there.
- Keep prefix names aligned with the existing taxonomy, including `b` for
  buffers, `f` for files, `s` for raw-text search, `n` for notes, `c` for code,
  `g` for version control, `h` for help, and `w` for windows.
- Preserve project semantics documented near the global leader table. Do not
  silently substitute the process working directory for the current project.

After documenting the design, ask whether to implement it. Do not implement
from a recommendation-only or planning-only request. Treat an explicit request
to implement the binding as approval without asking again.

## Implement In Emacs

1. Read the relevant `use-package` block and the current keymap definitions in
   `dotfiles/emacs/init.el` before editing.
2. Use native `keymap-set`, `keymap-unset`, and `defvar-keymap`; do not add
   `general.el` or another keybinding DSL. Use `keymap-set` directly for
   non-leader bindings in Evil's global state maps. Use the existing
   `my/keymap-set-many` helper when one binding intentionally applies to several
   state maps.
   Choose the binding API according to scope:
   - Use `keymap-set` for global, state-independent bindings and ordinary Emacs
     mode maps whose behavior does not depend on Evil state.
   - Use `keymap-set` on `evil-normal-state-map`, `evil-insert-state-map`, or
     another Evil state map for global bindings specific to that state.
   - Use `evil-define-key` when a binding requires both a particular major or
     minor mode and one or more particular Evil states.
   - Define named leader and localleader prefix maps with `defvar-keymap` and
     populate those maps normally. Attach a global leader to Evil's global state
     maps, but attach a mode-local leader with `evil-define-key`.
   Do not mechanically replace global `keymap-set` calls with
   `evil-define-key`; the former communicates their global state-map scope more
   directly. Use `evil-make-intercept-map` or other precedence mechanisms only
   when a verified higher-priority Evil or minor-mode map prevents the intended
   mode-specific binding from winning.
3. Define every leader or localleader prefix as a named `defvar-keymap` with a
   useful `:doc` string. Add explicit labels with
   `which-key-add-keymap-based-replacements`, retaining the child map in the
   replacement with `(cons "label" child-map)` so the label does not replace
   its bindings.
4. Bind the global leader in only the intended Evil states after Evil loads.
   For mode-specific Evil bindings, wait for the mode to load and use
   `evil-define-key` with explicit states so Evil map precedence does not hide a
   direct mode-map binding. Preserve native Emacs prefixes unless the agreed
   design explicitly replaces them.
5. Prefer built-in commands or existing packages over custom functions. Use a
   custom wrapper only when it supplies a real semantic difference, sequencing,
   fallback, project behavior, or cross-editor consistency.
6. Put package-specific settings and custom functions in the `use-package`
   block for the package that defines the underlying behavior. Keep only
   genuinely Evil-specific helpers and wrappers near the Evil keybinding
   section. Keep the implementation in `dotfiles/emacs/init.el` until its size
   or stability justifies extracting a module.
7. Follow repository naming conventions: `my/` for commands, `my--` for private
   helpers, predicate names ending in `-p`, and `#'` for function references.
8. Add ERT tests in `dotfiles/emacs/tests/init-test.el` for every custom function.
   Test its behavior directly; do not use ERT merely to retest the key mapping.
9. Use the `test-emacs-config` skill. Run the ERT suite when custom behavior
   changed and always run a configuration smoke test. Use a focused read-only
   key lookup when direct mapping verification is valuable; do not maintain a
   separate assertion list that duplicates `docs/editor-keybindings.org`.

## Implement In Neovim

1. Read `dotfiles/nvim/lua/config/keymap.lua` and the relevant plugin or config
   modules before editing. Follow existing plugin-spec mapping patterns when a
   plugin owns the behavior.
2. Keep `keymap.lua` focused on mappings. Put reusable custom behavior in an
   appropriately scoped module under `dotfiles/nvim/lua/config/actions/` or the
   nearest established module.
3. Prefer Neovim built-ins or existing plugins over new custom logic or new
   dependencies. Use structured APIs rather than parsing command output.
4. Give mappings concise `desc` values so which-key remains useful. Add or
   update which-key group metadata for new leader prefixes.
5. Add MiniTest tests for every custom function. Mirror the source path under
   `dotfiles/nvim/tests/lua/`; for example,
   `lua/config/actions/files.lua` is tested by
   `tests/lua/config/actions/files_test.lua`. Do not use Plenary.
6. Test function logic directly rather than only asserting that a key exists.
   Add a focused mapping assertion separately when the binding itself changed.
7. Use the `test-neovim-config` skill. Run the MiniTest suite, a focused mapping
   assertion, and a configuration smoke test.

## Finish

1. Reconcile the implemented behavior with `docs/editor-keybindings.org` so its
   provider and function cells describe reality.
2. Run `ec` only on files changed for the task and run `git diff --check` on
   those files.
3. Report the final behavior by editor, the important implementation choices,
   and the tests run. State any validation that could not be completed.
