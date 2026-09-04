---@brief
---
--- Native Roslyn Language Server configuration, based on the upstream
--- nvim-lspconfig definition without depending on that plugin.

local diagnostic_group = vim.api.nvim_create_augroup('my.roslyn_ls', { clear = true })

local function find_root(bufnr)
    return vim.fs.root(bufnr, function(name)
        return name:match('%.slnx?$') ~= nil
    end) or vim.fs.root(bufnr, function(name)
        return name:match('%.csproj$') ~= nil
    end)
end

local function notify_workspace_open(client)
    local root_dir = client.config.root_dir
    for entry, entry_type in vim.fs.dir(root_dir) do
        if entry_type == 'file' and (vim.endswith(entry, '.sln') or vim.endswith(entry, '.slnx')) then
            client:notify('solution/open', {
                solution = vim.uri_from_fname(vim.fs.joinpath(root_dir, entry)),
            })
            return
        end
    end

    local projects = {}
    for entry, entry_type in vim.fs.dir(root_dir) do
        if entry_type == 'file' and vim.endswith(entry, '.csproj') then
            table.insert(projects, vim.uri_from_fname(vim.fs.joinpath(root_dir, entry)))
        end
    end
    if #projects > 0 then
        client:notify('project/open', { projects = projects })
    end
end

local function refresh_diagnostics(client)
    local capabilities = vim
        .iter(client.dynamic_capabilities.capabilities.diagnosticProvider or {})
        :map(function(capability)
            return capability.registerOptions.identifier
        end)
        :totable()

    for bufnr in pairs(client.attached_buffers) do
        if vim.api.nvim_buf_is_loaded(bufnr) then
            for _, identifier in ipairs(capabilities) do
                client:request('textDocument/diagnostic', {
                    identifier = identifier,
                    textDocument = vim.lsp.util.make_text_document_params(bufnr),
                }, nil, bufnr)
            end
        end
    end
end

local function project_initialization_complete(_, _, context)
    local client = assert(vim.lsp.get_client_by_id(context.client_id))
    refresh_diagnostics(client)
    return vim.NIL
end

local function attach_diagnostic_refresh(client, bufnr)
    if vim.api.nvim_get_autocmds({ buffer = bufnr, group = diagnostic_group })[1] then
        return
    end

    vim.api.nvim_create_autocmd({ 'BufWritePost', 'InsertLeave' }, {
        group = diagnostic_group,
        buffer = bufnr,
        callback = function()
            refresh_diagnostics(client)
        end,
        desc = 'Refresh Roslyn diagnostics',
    })
end

---@type vim.lsp.Config
return {
    name = 'roslyn_ls',
    cmd = { 'roslyn-language-server', '--stdio' },
    filetypes = { 'cs' },
    root_dir = function(bufnr, on_dir)
        local root_dir = find_root(bufnr)
        if root_dir then
            on_dir(root_dir)
        end
    end,
    on_init = { notify_workspace_open },
    on_attach = attach_diagnostic_refresh,
    handlers = {
        ['workspace/projectInitializationComplete'] = project_initialization_complete,
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
