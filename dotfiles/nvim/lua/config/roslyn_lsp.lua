local M = {}

local diagnostic_group = vim.api.nvim_create_augroup('my.roslyn_ls', { clear = true })

function M.find_root(bufnr)
    return vim.fs.root(bufnr, function(name)
        return name:match('%.slnx?$') ~= nil
    end) or vim.fs.root(bufnr, function(name)
        return name:match('%.csproj$') ~= nil
    end)
end

function M.notify_workspace_open(client)
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

function M.refresh_diagnostics(client)
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

function M.project_initialization_complete(_, _, context)
    local client = assert(vim.lsp.get_client_by_id(context.client_id))
    M.refresh_diagnostics(client)
    return vim.NIL
end

function M.attach_diagnostic_refresh(client, bufnr)
    if vim.api.nvim_get_autocmds({ buffer = bufnr, group = diagnostic_group })[1] then
        return
    end

    vim.api.nvim_create_autocmd({ 'BufWritePost', 'InsertLeave' }, {
        group = diagnostic_group,
        buffer = bufnr,
        callback = function()
            M.refresh_diagnostics(client)
        end,
        desc = 'Refresh Roslyn diagnostics',
    })
end

return M
