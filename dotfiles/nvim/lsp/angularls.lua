---@brief
---
--- Native Angular Language Service configuration, based on the upstream
--- nvim-lspconfig definition without depending on that plugin.

local angular_lsp = require('config.angular_lsp')

---@type vim.lsp.Config
return {
    cmd = function(dispatchers, config)
        local root_dir = (config and config.root_dir) or vim.fn.getcwd()
        return vim.lsp.rpc.start(angular_lsp.command(root_dir), dispatchers)
    end,
    filetypes = { 'typescript', 'html', 'typescriptreact', 'htmlangular' },
    root_markers = { 'angular.json', 'nx.json' },
    root_dir = function(bufnr, on_dir)
        local root_dir = angular_lsp.find_root(bufnr)
        if root_dir then
            on_dir(root_dir)
        end
    end,
}
