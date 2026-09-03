# Emacs and Neovim LSP Configuration Plan

## Objective

Add a shared, review-oriented coding environment to Emacs and Neovim for:

- Java
- JavaScript and TypeScript
- React with JSX and TSX
- Angular, including inline and external templates
- Python
- C#

The configuration should provide syntax highlighting, diagnostics, completion,
hover documentation, definitions, declarations, references, implementations,
type definitions, symbols, call hierarchy, code actions, rename, and explicit
formatting where supported.

Neovim remains responsible for installing and updating tree-sitter parsers and
language-server executables. Emacs consumes those installations rather than
maintaining separate copies.

## Agreed Constraints

- Continue using Emacs 30.2.
- Use built-in Eglot as the Emacs LSP client.
- Use `eglot-hierarchy` as a temporary Emacs 30 call-hierarchy bridge.
- Use Rassumfrassum to combine TypeScript and Angular language servers in
  Angular buffers.
- Keep Neovim's native 0.11/0.12 `vim.lsp.config` architecture.
- Do not add `nvim-lspconfig`, `roslyn.nvim`, or another general LSP
  configuration plugin.
- It is acceptable to vendor relevant server configuration from
  `nvim-lspconfig` into `dotfiles/nvim/lsp/`.
- Use Mason as the package manager for language servers used by both editors.
- Use nvim-treesitter as the parser manager for both editors.
- Keep diagnostics enabled.
- Add linters, formatters, automatic formatting, or save hooks only to achieve
  parity with behavior already enabled in Neovim.
- Do not add Corfu. Eglot completion remains available manually through
  `completion-at-point`, normally invoked with `M-TAB` or `C-M-i`.
- Do not override `gq` in Emacs.
- Do not mirror Neovim's LSP meanings for `C-s` or `C-]` in Emacs.
- Do not implement code-lens execution in Emacs 30. Document `SPC c x` and
  `grx` as N/I for Emacs.

## Tool Ownership

### Tree-sitter parsers

nvim-treesitter installs parsers under:

```text
~/.local/share/nvim/site/parser
```

Emacs will add that directory to `treesit-extra-load-path`.

Add a nearby comment explaining that the Emacs 31 upgrade should reconsider
this arrangement and evaluate `treesit-install-language-grammar` together with
`treesit-auto-install-grammar`.

### Language servers

Mason installs tools under Neovim's data directory and exposes executables in:

```text
~/.local/share/nvim/mason/bin
```

Emacs will add that directory to both `exec-path` and the `PATH` environment
passed to child processes. Paths must be derived from the user's home
directory rather than hard-coded to `/home/sean`.

Adding a language server for Emacs requires all of the following:

1. Add or vendor its native Neovim config under `dotfiles/nvim/lsp/`.
2. Add its Neovim server name and Mason package name to
   `dotfiles/nvim/lua/config/lsp_servers.lua`.
3. Allow the existing `mason-tool-installer` configuration to include the
   package in `ensure_installed`.
4. Start Neovim or use Mason so the package is downloaded.
5. Add the applicable major mode, server command, and Eglot startup behavior
   to the Emacs configuration.

No separate Emacs server-download script will be added.

## Documentation Changes

Update these documents during implementation:

### `docs/editor-keybindings.org`

- Make the Emacs `SPC c` prefix and agreed code bindings authoritative.
- Record the actual provider and function for both editors.
- Add the approved Neovim-default normal-mode bindings to Emacs.
- Record `SPC c x` and `grx` as N/I for Emacs.
- Preserve `C-s`, `C-]`, and `gq` as editor-specific behavior rather than
  claiming semantic parity.
- Add `SPC c f` as the shared explicit region-or-buffer formatting command.

### `dotfiles/emacs/README.org`

- Explain the tree-sitter and Eglot architecture.
- Document the shared Neovim parser and Mason paths.
- Explain that Emacs completion is manually invoked because no automatic
  completion frontend such as Corfu is installed.
- Document Angular multi-server behavior through Rassumfrassum.
- Document the Emacs 31 migration notes for parser installation and call
  hierarchy.

### `dotfiles/nvim/README.md`

- Explain that Neovim uses native `vim.lsp.config` files rather than
  `nvim-lspconfig`.
- State that Mason also manages the executables consumed by Emacs.
- Document the shared-language-server addition workflow described above.
- Document that nvim-treesitter parsers are consumed by Emacs.

### `roles/runtimes/dotnet/README.md`

- Explain that the role installs Fedora's .NET SDK.
- Explain that the SDK is required to run Mason's Roslyn language-server
  package.
- Clarify that Mason installs Roslyn but does not install the .NET runtime.

## Runtime Role

Create a new `dotnet` role under `roles/runtimes/`:

```text
roles/runtimes/dotnet/
├── README.md
└── tasks/main.yml
```

Use `ansible.builtin.package` to install Fedora's `dotnet-sdk-10.0` package.
Do not add Microsoft's package repository or an installation script.

Add the role to both workstation playbooks:

- `desktop22.yml`
- `desktop25.yml`

Follow existing runtime-role and repository YAML conventions.

## Neovim Language Servers

Continue enabling servers through the existing loop over
`config.lsp_servers` and native configuration files under
`dotfiles/nvim/lsp/`.

The relevant Mason-managed executables are:

| Language | Neovim server | Mason package | Executable |
|---|---|---|---|
| Java | `jdtls` | `jdtls` | `jdtls` |
| JavaScript/TypeScript/React | `ts_ls` | `typescript-language-server` | `typescript-language-server` |
| Angular | `angularls` | `angular-language-server` | `ngserver` |
| Angular multiplexer | not enabled as a standalone Neovim LSP | `rassumfrassum` | `rass` |
| Python | `pyright` | `pyright` | `pyright-langserver` |
| C# | `roslyn_ls` | `roslyn-language-server` | `roslyn-language-server` |

Add `angularls` and `roslyn_ls` to
`dotfiles/nvim/lua/config/lsp_servers.lua`. Ensure Rassumfrassum is also part
of Mason's derived installation set without enabling it as another Neovim LSP
client.

### Roslyn

Create `dotfiles/nvim/lsp/roslyn_ls.lua` as a native `vim.lsp.Config`.
Vendor only the configuration needed for:

- The `roslyn-language-server` command and stdio transport
- C# filetypes
- Appropriate `.sln`, `.slnx`, and project root markers
- Normal workspace behavior needed for code review

Do not add `nvim-lspconfig` or `roslyn.nvim`. Reconsider `roslyn.nvim` only if
testing reveals a concrete need such as inadequate solution selection or
generated-source navigation.

### Angular

Create `dotfiles/nvim/lsp/angularls.lua` as a native `vim.lsp.Config`, using
the relevant upstream configuration as a source. It must:

- Run `ngserver` over stdio.
- Support TypeScript, TypeScript React, HTML, and Angular HTML filetypes as
  appropriate.
- Recognize `angular.json` and `nx.json` workspace markers.
- Supply the TypeScript and Angular probe locations expected by the server.
- Supply the Angular core version when available.

Neovim may attach both `ts_ls` and `angularls` to Angular TypeScript buffers,
using its native multi-client support.

## Emacs Tree-sitter Modes

Configure these associations:

| Files | Emacs mode | Shared parser |
|---|---|---|
| `.java` | `java-ts-mode` | `java` |
| `.js`, `.mjs`, `.cjs`, `.jsx` | `js-ts-mode` | `javascript` |
| `.ts` | `typescript-ts-mode` | `typescript` |
| `.tsx` | `tsx-ts-mode` | `tsx` |
| `.py` | `python-ts-mode` | `python` |
| `.cs` | `csharp-ts-mode` | `c_sharp` |
| Angular component `.html` | `html-ts-mode` | `html` |

React does not require a separate major mode, parser, or language server.
JavaScript React uses `js-ts-mode`; TypeScript React uses `tsx-ts-mode`.

Emacs has no built-in `angular-ts-mode`. Use `html-ts-mode` for structural
highlighting of external templates and let Angular LSP provide Angular-aware
semantics. Do not attempt to force Neovim's `angular` parser into an unrelated
Emacs mode.

## Eglot Server Selection

Enable Eglot automatically for the Java, JavaScript, TypeScript, TSX, Python,
and C# tree-sitter modes.

Use these direct server commands outside Angular workspaces:

| Modes | Command |
|---|---|
| `java-ts-mode` | `jdtls` |
| `js-ts-mode`, `typescript-ts-mode`, `tsx-ts-mode` | `typescript-language-server --stdio` |
| `python-ts-mode` | `pyright-langserver --stdio` |
| `csharp-ts-mode` | `roslyn-language-server --stdio` |

### Angular multi-server selection

Angular Language Service supplements rather than replaces the ordinary
TypeScript server. Eglot still manages one LSP connection per buffer, so use
Rassumfrassum as the single visible connection for Angular projects:

```text
Eglot -> rass -> typescript-language-server
              -> angular-language-server
```

Project selection must:

1. Search upward from the current file for the nearest `angular.json` or
   `nx.json`.
2. Use that directory as the Angular workspace even when the Git project root
   is higher.
3. Return a Rassumfrassum command combining TypeScript LS and Angular LS for
   Angular TypeScript, TSX, and external template buffers.
4. Return plain TypeScript LS for JavaScript, TypeScript, React, and TSX outside
   Angular workspaces.
5. Avoid starting Angular LS for ordinary non-Angular HTML files.
6. Let external Angular HTML templates join the same multiplexed workspace as
   their component TypeScript files.

The Angular command builder must supply the same probe locations and Angular
version information as the native Neovim configuration. Custom project
detection and command-building functions require ERT coverage.

## Diagnostics and Other Automatic Behavior

Match behavior already enabled in Neovim:

- Keep Eglot's Flymake diagnostics enabled.
- Keep LSP completion available through Emacs's standard
  `completion-at-point` integration.
- Do not install Corfu or another automatic completion frontend.
- Document `M-TAB` and `C-M-i` as the normal manual completion entry points.
- Enable semantic-token highlighting when supported, matching Neovim's LSP
  semantic highlighting.
- Keep inlay hints disabled by default because they are not enabled in the
  Neovim configuration. They may remain available interactively.
- Disable automatic on-type formatting unless testing proves equivalent
  behavior is already enabled in Neovim.
- Do not add general format-on-save behavior.
- Preserve existing unrelated save-time behavior in each editor.

## Emacs 30 Call Hierarchy

Install `eglot-hierarchy` and configure its incoming and outgoing call trees.
Place an explicit comment around the package and associated compatibility
wrappers:

```elisp
;; Emacs 30 compatibility. This package and its associated wrappers are safe
;; to remove when upgrading to Emacs 31 and adopting Eglot's native
;; call-hierarchy commands.
```

The package's command shows incoming calls by default and outgoing calls when
called with a prefix argument. Add a small `my/` command for the outgoing-call
case and cover it with ERT.

## Unified Keybindings

Update `docs/editor-keybindings.org` before implementing the bindings.

### Leader bindings

Implement the complete shared `SPC c` family except code lens in Emacs:

| Key | Behavior | Emacs implementation |
|---|---|---|
| `SPC c a` | Code action | `eglot-code-actions` |
| `SPC c d` | Definition | `xref-find-definitions` |
| `SPC c D` | Declaration | `eglot-find-declaration` |
| `SPC c f` | Format active region or buffer | `eglot-format` |
| `SPC c h` | Hover documentation | `eldoc-doc-buffer` |
| `SPC c I` | Implementations | `eglot-find-implementation` |
| `SPC c i` | Incoming call hierarchy | `eglot-hierarchy-call-hierarchy` |
| `SPC c n` | Rename | `eglot-rename` |
| `SPC c o` | Outgoing call hierarchy | tested `my/` wrapper |
| `SPC c r` | References | `xref-find-references` |
| `SPC c s` | Document symbols | `consult-imenu` |
| `SPC c S` | Workspace symbols | `xref-find-apropos` |
| `SPC c t` | Type definition | `eglot-find-typeDefinition` |
| `SPC c x` | Run code lens | N/I in Emacs 30 |

Add `SPC c f` to Neovim as an explicit region-or-buffer formatting command.
Do not add format-on-save.

Configure Emacs Xref definitions and reference results to use `consult-xref`
for a searchable list with preview.

### Non-leader bindings

Implement Emacs parity with the applicable Neovim 0.12 defaults and the
existing custom `gd` mapping:

| Key | Mode | Behavior | Emacs status |
|---|---|---|---|
| `gd` | normal | Definition | Implement |
| `gra` | normal and visual | Code action | Implement |
| `gri` | normal | Implementations | Implement |
| `grn` | normal | Rename | Implement |
| `grr` | normal | References | Implement |
| `grt` | normal | Type definition | Implement |
| `grx` | normal | Run code lens | N/I in Emacs 30 |
| `gO` | normal | Document symbols | Implement |
| `K` | normal | Hover documentation | Implement |

Do not mirror these Neovim defaults in Emacs:

- `C-s` for signature help, because `C-s` is deliberately the shared save key.
- `C-]` for definition, because it should retain established Evil tag
  navigation and `gd` already provides definition lookup.
- `gq` for LSP formatting, because Evil uses it as a text-filling operator and
  a correct hybrid LSP/fill operator would require disproportionate custom
  behavior.

Keep `gq` editor-native and use `SPC c f` for explicit cross-editor formatting.

## Code-lens Limitation

Emacs 30's Eglot advertises the code-lens capability but does not expose a
user command that requests and executes code lenses. Implementing it would
require custom JSON-RPC handling and a selection UI.

Do not build that custom implementation. Preserve Neovim's `SPC c x` and
default `grx`, and document both bindings as N/I for Emacs. Revisit this after
an Emacs/Eglot upgrade or if code lens becomes important enough to justify a
dedicated implementation.

## TypeScript and Parser Updates

As part of implementation:

1. Update nvim-treesitter.
2. Update all installed nvim-treesitter parsers because the configuration
   installs `"all"`.
3. Update the Mason registry.
4. Update `typescript-language-server` and its installed TypeScript dependency.
5. Install or update `angular-language-server`, `rassumfrassum`, and
   `roslyn-language-server`.
6. Update applicable entries in `dotfiles/nvim/lazy-lock.json`.
7. Compare the vendored `ts_ls` native configuration with its current upstream
   source and incorporate relevant compatible corrections without installing
   `nvim-lspconfig`.

## Validation

### Ansible

- Verify the Fedora .NET package name.
- Run an Ansible syntax check for both changed workstation playbooks.
- Run `ansible-lint` using the repository's Ansible-command guidance.
- Confirm the new role is idempotent in structure and follows repository YAML
  conventions.

### Neovim

- Use the `test-neovim-config` skill.
- Run the configuration smoke test.
- Verify the derived Mason `ensure_installed` set includes:
  - `typescript-language-server`
  - `angular-language-server`
  - `rassumfrassum`
  - `roslyn-language-server`
- Verify `roslyn_ls` and `angularls` use native configuration files.
- Verify no `nvim-lspconfig` dependency is introduced.
- Verify all custom and default LSP mappings.
- Verify `SPC c f` in normal and visual use as designed.
- Add MiniTest coverage for custom native server behavior where appropriate.
- Test TypeScript, React, Angular, and Roslyn attachment against representative
  projects when available.

### Emacs

- Use the `test-emacs-config` skill.
- Run the complete ERT suite and configuration smoke test.
- Verify every target file extension selects the intended tree-sitter mode.
- Verify Emacs can load the required Neovim parser libraries.
- Verify Emacs can resolve every Mason executable.
- Verify direct Eglot startup for Java, JavaScript/TypeScript/React, Python, and
  C#.
- Verify Angular TypeScript and template buffers select Rassumfrassum.
- Verify ordinary TypeScript/React selects TypeScript LS directly.
- Verify ordinary HTML does not start Angular LS.
- Verify Flymake diagnostics, definitions, references, implementations,
  declarations, symbols, type definitions, code actions, rename, formatting,
  and hierarchy where supported.
- Add ERT coverage for all new custom Emacs functions.
- Verify code-lens bindings remain intentionally unimplemented.

### Final checks

- Run `ec` only on files changed by this implementation.
- Run `git diff --check` on the changed files.
- Reconcile `docs/editor-keybindings.org` with the final implementation.
- Report any feature a language server does not advertise or any live
  integration test that cannot be completed locally.
