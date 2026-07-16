# Neovim

## LSP Configuration

This config uses Neovim's native LSP support.

Each language server has a config file in `lsp/`. The filename is the Neovim LSP server name:

```text
lsp/lua_ls.lua
lsp/pyright.lua
lsp/ts_ls.lua
```

Those files define the server command, filetypes, root markers, and any server-specific settings.

Enabled servers are listed in `lua/config/lsp_servers.lua`. This file maps the Neovim LSP server name to the Mason package name:

```lua
return {
    lua_ls = "lua-language-server",
    pyright = "pyright",
    ts_ls = "typescript-language-server",
}
```

`lua/config/lsp.lua` enables every server listed in that table with `vim.lsp.enable()`.

`lua/plugins/mason_tool_installer.lua` reads the same table and installs the Mason packages automatically.

### Adding a New LSP

1. Add an LSP config file under `lsp/`. You'll likely want to copy the settings from [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig/tree/master/lsp).

   Example:

   ```lua
   -- lsp/example_ls.lua
   return {
       cmd = { 'example-language-server', '--stdio' },
       filetypes = { 'example' },
       root_markers = { 'example.json', '.git' },
   }
   ```

2. Add the server to `lua/config/lsp_servers.lua`.

   The key must match the filename without `.lua`. The value must be the Mason package name:

   ```lua
   return {
       example_ls = "example-language-server",
   }
   ```

3. Restart Neovim or run `:Lazy reload mason-tool-installer.nvim`.

Mason Tool Installer will install the package. Neovim will enable the LSP when a matching filetype is opened.

Use `:checkhealth vim.lsp` to verify that the executable is installed and the configuration is valid.

## Tests

Run the [mini.test](https://github.com/nvim-mini/mini.test) unit tests through the configured Neovim installation:

```sh
nvim --headless "+luafile $HOME/.config/nvim/scripts/minitest.lua"
```

To run the same test suite from within Neovim:

```vim
:luafile ~/.config/nvim/scripts/minitest.lua
```
