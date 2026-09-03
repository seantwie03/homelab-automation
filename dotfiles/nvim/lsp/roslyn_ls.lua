---@brief
---
--- Native Roslyn Language Server configuration, based on the upstream
--- nvim-lspconfig definition without depending on that plugin.

local roslyn_lsp = require('config.roslyn_lsp')

---@type vim.lsp.Config
return {
    name = 'roslyn_ls',
    cmd = { 'roslyn-language-server', '--stdio' },
    filetypes = { 'cs' },
    root_dir = function(bufnr, on_dir)
        local root_dir = roslyn_lsp.find_root(bufnr)
        if root_dir then
            on_dir(root_dir)
        end
    end,
    on_init = { roslyn_lsp.notify_workspace_open },
    on_attach = roslyn_lsp.attach_diagnostic_refresh,
    handlers = {
        ['workspace/projectInitializationComplete'] = roslyn_lsp.project_initialization_complete,
    },
    capabilities = {
        textDocument = {
            diagnostic = {
                dynamicRegistration = true,
            },
        },
    },
    settings = {
        ['csharp|background_analysis'] = {
            dotnet_analyzer_diagnostics_scope = 'fullSolution',
            dotnet_compiler_diagnostics_scope = 'fullSolution',
        },
        ['csharp|symbol_search'] = {
            dotnet_search_reference_assemblies = true,
        },
        ['csharp|code_lens'] = {
            dotnet_enable_references_code_lens = true,
        },
    },
}
