# Slide Authoring Snippets

## Problem

Presentation slides are authored in Markdown with JSX-style components for emphasis.
Applying emphasis is almost always a *wrapping* operation on text that already exists:

```
Some text          →    <AccentText>Some text</AccentText>
```

Typing the tag pair by hand is slow and error-prone, and it happens constantly. The
component set is not small and is expected to grow:

| Kind | Components (illustrative, not exhaustive) | Shape |
|---|---|---|
| Inline text | `AccentText`, `DangerText`, `InfoText`, `SuccessText`, `WarningText` | wraps inline, no newlines |
| Block | `Callout`, `TerminalWindow` | newline after open tag, newline before close tag |

The inline components share a `Text` suffix, so only the stem (`Accent`, `Danger`, …)
needs to be selected. The block components need their delimiters on their own lines.

## Decision Status

As of **2026-08-16**, undecided.

**Decided:** adopt `evil-surround` (Emacs, MELPA) and `nvim-surround`
(`kylechui/nvim-surround`, Neovim). These were chosen over alternatives because
`nvim-surround` is a deliberate vim-surround clone, so both editors use identical
keys out of the box: `ys{motion}{char}`, `S{char}` in visual state, `cs{old}{new}`,
`ds{char}`, plus the uppercase `yS`/`gS` variants that place delimiters on their own
lines. `mini.surround` was rejected despite `mini.nvim` already being a dependency,
because its defaults are `sa`/`sd`/`sr` and matching the Emacs key layout requires
extra remapping work.

**Undecided:** how a specific component gets selected once the surround operator is
invoked. Four candidate designs are documented below.

## Constraints

1. **Editor parity is a hard requirement.** Any design must produce the same
   keystrokes in Emacs and Neovim. This was the condition for adopting surround
   plugins at all.
2. **The component set will grow.** A design that consumes one key per component has
   a finite budget and will eventually force non-mnemonic key choices.
3. **Repository conventions apply.** Per `AGENTS.md`: keybinding changes update
   `docs/editor-keybindings.org`, custom functions get tests in
   `dotfiles/emacs/tests` and `dotfiles/nvim/tests`, and Emacs/Neovim configs stay in
   sync.

## Current State

Verified in this repository and in the running Emacs session on 2026-08-16:

- Neither editor has a surround package, snippet engine, or abbrev configuration
  today. `evil-surround`, `yasnippet`, `tempel`, and `mini.surround` are all absent.
- MELPA is configured in the Emacs package archives, so `evil-surround` is
  installable without adding an archive.
- In `my/markdown-localleader-map`, the keys `. b e f l p s x` are taken. All others
  are free.
- Nothing overrides `vim.ui.select` or `vim.ui.input` in the Neovim config.
  `snacks.nvim` has only the `image` module enabled and `telescope-ui-select` is not
  installed, so the default blocking implementations are in effect. **This is load
  bearing — see the async trap under Option A.**
- `which-key-show-keymap` and `which-key--show-keymap` are both available in the
  running Emacs.
- `read-char` accepts a PROMPT argument, which is what makes the echo-area hint line
  in Options B and C free.
- `dotfiles/nvim/after/ftplugin/markdown.lua` already exists and is the natural home
  for the Neovim side of any of these options.

## Shared Mechanism

All four options rest on the same capability: **both plugins allow the "add" side of
a surround to be a function rather than a static pair.** This is not a workaround —
it is how each plugin implements its own built-in tag (`t`) and function (`f`)
surrounds. Emacs ships `(?t . evil-surround-read-tag)` in
`evil-surround-pairs-alist`; the designs below substitute a custom reader.

Two consequences that hold for every option:

- **Only the add direction needs customizing.** `dst` and `cst` are driven by tag
  matching, not by the configured pair, so deleting and changing a component tag
  works on all components with no extra configuration. The removal path never has to
  be written.
- **`t` gets overloaded.** After overriding `t`, `ysiwt` means "component" while
  `dst` still means "any tag". The escape hatch for wrapping in an arbitrary tag
  differs per editor: `<` in Emacs (also bound to `evil-surround-read-tag` by
  default), `T` in Neovim. `c` is free as a surround target in both plugins.

Keeping a `t`/`c` prefix rather than flattening to bare characters (`ysiwa`) is
deliberate: `a`, `b`, `B`, `r`, `q`, `s`, and `f` are all built-in surround targets
in these plugins, and the prefix fences the component namespace off from the
plugin's own.

---

## Option A — Single key, then a text prompt

`ysiwt` prompts for a component name with completion. `ysiwc` does the same for
block components.

### Emacs

```elisp
(defvar my--markdown-text-components
  '("Accent" "Danger" "Info" "Success" "Warning")
  "Markdown inline text component names, without the Text suffix.")

(defvar my--markdown-block-components
  '("Callout" "TerminalWindow")
  "Markdown block-level component names.")

(defvar my--markdown-component-history nil
  "Minibuffer history of Markdown component names.")

(defun my/markdown-surround-text-component ()
  "Read an inline text component and return its surround pair."
  (let ((name (completing-read "Text component: "
                               my--markdown-text-components
                               nil 'confirm nil
                               'my--markdown-component-history)))
    (cons (format "<%sText>" name) (format "</%sText>" name))))

(defun my/markdown-surround-block-component ()
  "Read a block component and return its surround pair."
  (let ((name (completing-read "Block component: "
                               my--markdown-block-components
                               nil 'confirm nil
                               'my--markdown-component-history)))
    (cons (format "<%s>\n" name) (format "\n</%s>" name))))

(defun my/markdown-add-surround-pairs ()
  "Add Markdown component surround pairs to the current buffer."
  (setq-local evil-surround-pairs-alist
              (append (list (cons ?t #'my/markdown-surround-text-component)
                            (cons ?c #'my/markdown-surround-block-component))
                      evil-surround-pairs-alist)))
```

Consing onto the front shadows the default `?t` entry by `assoc` order, so nothing
needs to be deleted. `setq-local` is used rather than a bare `push` because
`evil-surround` may or may not already make that variable buffer-local; this form is
correct either way.

This option benefits from the existing completion stack for free: `fido-vertical-mode`
plus `orderless` gives live vertical filtering, and because `completions-sort` is
already `'historical`, passing a history variable floats the most recently used
component to the top. `'confirm` as REQUIRE-MATCH allows a brand-new component name
to be used without editing the list first.

### Neovim

```lua
-- in after/ftplugin/markdown.lua
local function prompt(label)
    local name = require("nvim-surround.config").get_input(label)
    return (name and name ~= "") and name or nil
end

require("nvim-surround").buffer_setup({
    surrounds = {
        ["t"] = {
            add = function()
                local name = prompt("Text component: ")
                if not name then return nil end
                return { { "<" .. name .. "Text>" }, { "</" .. name .. "Text>" } }
            end,
        },
        ["c"] = {
            add = function()
                local name = prompt("Block component: ")
                if not name then return nil end
                return { { "<" .. name .. ">", "" }, { "", "</" .. name .. ">" } }
            end,
        },
    },
})
```

`add` returns two lists of *lines*, so `{ "<Callout>", "" }` expresses "opening tag,
then an empty line" natively instead of embedding `\n`. Returning `nil` aborts the
operator cleanly.

### The async trap

Do **not** use `vim.ui.select(...)` with a callback inside `add`. The `add` function
must return synchronously. The default `vim.ui.select` blocks (it is `inputlist`
underneath), so it would appear to work in the current configuration — but enabling
`snacks.picker` or adding `telescope-ui-select` makes the callback async, `add`
returns `nil`, and the surround silently does nothing. `get_input` is
`nvim-surround`'s own synchronous, `<Esc>`-safe helper and is the durable choice. Its
cost is a free-text prompt with no list filtering; `vim.fn.input` with
`completion = "customlist,..."` can add Tab-completion, but the completion callback
has to be reachable from Vimscript.

---

## Option B — `t`/`c` prefix, then one character

`ysiwta` → `<AccentText>`. Fixed keystroke count, no prompt.

### Emacs

```elisp
(defvar my--markdown-text-components
  '((?a . "Accent")
    (?d . "Danger")
    (?i . "Info")
    (?s . "Success")
    (?w . "Warning"))
  "Alist of key to Markdown inline text component name.")

(defun my/markdown-surround-text-component ()
  "Read a text component key and return its surround pair."
  (let* ((hints (mapconcat (lambda (entry)
                             (format "(%c)%s" (car entry) (cdr entry)))
                           my--markdown-text-components " "))
         (key (read-char (concat "Text component: " hints " ")))
         (name (alist-get key my--markdown-text-components)))
    (unless name
      (user-error "No text component bound to %c" key))
    (cons (format "<%sText>" name) (format "</%sText>" name))))
```

### Neovim

```lua
local text_components = {
    a = "Accent", d = "Danger", i = "Info", s = "Success", w = "Warning",
}

local function read_component(label, components)
    local hints = {}
    for key, name in pairs(components) do
        table.insert(hints, "(" .. key .. ")" .. name)
    end
    table.sort(hints) -- pairs() iteration order is not stable
    vim.api.nvim_echo({ { label .. " " .. table.concat(hints, " ") } }, false, {})
    local ok, char = pcall(vim.fn.getcharstr)
    vim.cmd("echo ''")
    return ok and components[char] or nil
end
```

The `read-char` PROMPT and the `nvim_echo` line give an echo-area palette that
carries the same information as a which-key popup on a single line. It appears
immediately rather than after the 0.5s which-key idle delay.

---

## Option C — Option B, with `?` falling back to Option A

The reader dispatches on a single character as in Option B, but reserves one
character (`?` or `<Space>`) that falls through to the `completing-read` /
`get_input` prompt from Option A:

```elisp
(if (eq key ??)
    (my/markdown-surround-text-component-by-name)
  ...)
```

This gives fixed-length keystrokes for frequently used components and unbounded
scale for the long tail. New components work through `?` immediately and can be
promoted to a dedicated character later without re-keying anything. Costs about five
extra lines per editor and no extra key budget.

---

## Option D — A real prefix keymap of Evil operators

Abandon the plugins' character dispatch for the add path. Define one Evil operator
per component, bound under a genuine multi-character prefix:

```elisp
(evil-define-operator my/markdown-surround-accent (beg end)
  "Wrap BEG to END in an <AccentText> element."
  (interactive "<r>")
  (save-excursion
    (goto-char end)
    (insert "</AccentText>")
    (goto-char beg)
    (insert "<AccentText>")))
;; bound at (kbd "g s a") in markdown-mode-map and gfm-mode-map
```

`gsaiw` composes operator and motion exactly as `ysiwta` does. The operators would
be generated from the component list with a `dolist` and closures in Elisp, and a
loop in Lua; Neovim mirrors it with `vim.keymap.set` plus `operatorfunc`.

This is the **only design where which-key works natively in both editors** (see
below), and it is the design most consistent with the rest of the configuration,
which annotates every leader map with `which-key-add-keymap-based-replacements` and
maintains a full binding table in `docs/editor-keybindings.org`.

Costs: the surround plugins are no longer used for the add path, though they still
earn their place for `dst`/`cst` and for everyday pairs like `ysiw)`. Roughly 25
lines per editor instead of 10, and one `docs/editor-keybindings.org` row per
component. A `{ "gs", group = "surround" }` entry joins the existing `<Leader>`
groups in `which_key.lua`.

---

## which-key Behavior

**Options A, B, and C get no which-key popup, in either editor.** which-key hooks
*keymap traversal*: it activates when pending input resolves to a keymap and then
introspects that keymap. After `ysiw`, the surround plugin calls `read-char` /
`getcharstr()` imperatively, so there is no keymap in play and which-key never
fires. This is inherent to how surround plugins read their target character — typing
`ysiw` and waiting does not list the built-in pairs (`b B r a t`) either. It is not a
regression introduced by any of these designs.

Three responses:

| Response | Emacs | Neovim | Parity |
|---|---|---|---|
| Echo-area hint line | `read-char` PROMPT | `nvim_echo` | identical |
| Synthetic which-key popup | `which-key--show-keymap` (internal API) | no equivalent | **breaks** |
| Real prefix keymap (Option D) | native | native | identical |

`which-key.nvim`'s `show()` targets real keymap prefixes and buffer-local keymaps,
not synthetic lists, so the middle row cannot be made symmetric. It is rejected on
the parity constraint.

---

## Comparison

| | A: prompt | B: prefix + char | C: hybrid | D: operator keymap |
|---|---|---|---|---|
| Keys to accent a word | `ysiwt`+`acc`+RET (~9) | `ysiwta` (6) | `ysiwta` (6) | `gsaiw` (5) |
| Keystroke count | variable | fixed | fixed for hot path | fixed |
| Flow interruption | modal prompt | none | none for hot path | none |
| which-key popup | no | no | no | **yes** |
| Discoverability | completion list | echo-area hints | echo-area hints | which-key + docs |
| Scales to many components | unbounded | one key each | unbounded | one key each |
| Ad-hoc component | no config change | must edit config | via `?` | must edit config |
| Cross-editor parity | diverges (UI polish) | identical | identical | identical |
| Lines of config per editor | ~10 | ~15 | ~20 | ~25 |
| `editor-keybindings.org` rows | 1 | 1 | 1 | one per component |

The main long-term risk in B and D is **key collisions**. `a d i s w` covers the
current five inline components cleanly, but the first same-initial pair —
`Callout`/`Card`, `Success`/`Subtitle`, `TerminalWindow`/`Tip` — forces an arbitrary
character and the mnemonic system starts to erode. Options A and C never have this
problem.

## Open Questions

Resolve before implementing:

1. **Dot-repeat.** Does `.` after a component surround re-apply cleanly, and does it
   differ between a character read (B/C/D) and a minibuffer prompt (A)? A character
   read at runtime is plausibly more robust than a prompt replay, and `nvim-surround`
   caches the last surround for dot-repeat, but the actual behavior of both plugins
   is unverified. This matters when accenting several words in a row and could decide
   the choice on its own. Two-minute check once the plugins are installed.
2. **Is `gs` free?** Needed only for Option D. Evil and Neovim are not believed to
   bind it; confirm with `describe-key` and `:verbose map gs`. Scoping the binding to
   the Markdown maps makes it moot in practice.
3. **`nvim-surround` partial spec merge.** Supplying only `add` for `t` should leave
   `find`/`delete`/`change` at their defaults, keeping `dst` working on nested tags.
   Confirm with a `dst` on a nested tag after install; if it does not inherit, the
   default `find`/`delete` fields must be copied in.
4. **`\n` versus a blank line for block components.** Whether MDX parses the interior
   of a `Callout` as Markdown may require a blank line rather than a single newline.
   One-character change in the format strings either way.
5. **Confidence note.** Claims about `evil-surround` and `nvim-surround` internals in
   this document come from their documentation, not from inspection — neither plugin
   is installed yet. Everything under *Current State* was verified directly.

## Implementation Checklist

Applies to whichever option is chosen:

- Add `evil-surround` to `dotfiles/emacs/init.el` with `global-evil-surround-mode`,
  and register component pairs buffer-locally from a `markdown-mode`/`gfm-mode` hook.
- Add `nvim-surround` under `dotfiles/nvim/lua/plugins/`, and call `buffer_setup`
  from `dotfiles/nvim/after/ftplugin/markdown.lua`.
- Keep the component list in both editors in sync. There is no shared format between
  a `defvar` and a Lua table, so this is the part of the design that will drift.
  Codegen for a list of this size costs more than the two-line edit it saves; accept
  the duplication and note it in both files.
- Update `docs/editor-keybindings.org` with the new bindings.
- Add ERT coverage in `dotfiles/emacs/tests` and a `mini.test` case in
  `dotfiles/nvim/tests` for the reader functions and the generated delimiters.
- Run the `test-emacs-config` and `test-neovim-config` skills.
