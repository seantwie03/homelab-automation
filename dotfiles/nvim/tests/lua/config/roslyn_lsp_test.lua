local eq = MiniTest.expect.equality
local new_set = MiniTest.new_set
local config = dofile(vim.fn.stdpath('config') .. '/lsp/roslyn_ls.lua')

local T = new_set()

T['find_root() prefers a solution root'] = function()
    local original_root = vim.fs.root
    local calls = 0
    vim.fs.root = function(_, matcher)
        calls = calls + 1
        eq(matcher(calls == 1 and 'workspace.slnx' or 'app.csproj'), true)
        return calls == 1 and '/tmp/solution' or '/tmp/project'
    end
    local root
    config.root_dir(1, function(value)
        root = value
    end)
    eq(root, '/tmp/solution')
    eq(calls, 1)
    vim.fs.root = original_root
end

T['notify_workspace_open() opens a solution'] = function()
    local root = vim.fn.tempname()
    vim.fn.mkdir(root, 'p')
    vim.fn.writefile({}, root .. '/workspace.sln')
    local notification
    local client = {
        config = { root_dir = root },
        notify = function(_, method, params)
            notification = { method, params }
        end,
    }
    config.on_init[1](client)
    eq(notification[1], 'solution/open')
    eq(notification[2].solution, vim.uri_from_fname(root .. '/workspace.sln'))
    vim.fn.delete(root, 'rf')
end

T['refresh_diagnostics() pulls each registered diagnostic set'] = function()
    local requests = {}
    local client = {
        attached_buffers = { [vim.api.nvim_get_current_buf()] = true },
        dynamic_capabilities = {
            capabilities = {
                diagnosticProvider = {
                    { registerOptions = { identifier = 'compiler' } },
                    { registerOptions = { identifier = 'analyzers' } },
                },
            },
        },
        request = function(_, method, params, _, bufnr)
            table.insert(requests, { method = method, params = params, bufnr = bufnr })
        end,
    }

    local original_get_client_by_id = vim.lsp.get_client_by_id
    vim.lsp.get_client_by_id = function()
        return client
    end
    config.handlers['workspace/projectInitializationComplete'](nil, nil, { client_id = 1 })
    vim.lsp.get_client_by_id = original_get_client_by_id

    eq(#requests, 2)
    eq(requests[1].method, 'textDocument/diagnostic')
    eq(requests[1].params.identifier, 'compiler')
    eq(requests[2].params.identifier, 'analyzers')
end

return T
