local roslyn_lsp = require('config.roslyn_lsp')
local eq = MiniTest.expect.equality
local new_set = MiniTest.new_set

local T = new_set()

T['find_root() prefers a solution root'] = function()
    local original_root = vim.fs.root
    local calls = 0
    vim.fs.root = function(_, matcher)
        calls = calls + 1
        eq(matcher(calls == 1 and 'workspace.slnx' or 'app.csproj'), true)
        return calls == 1 and '/tmp/solution' or '/tmp/project'
    end
    eq(roslyn_lsp.find_root(1), '/tmp/solution')
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
    roslyn_lsp.notify_workspace_open(client)
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

    roslyn_lsp.refresh_diagnostics(client)

    eq(#requests, 2)
    eq(requests[1].method, 'textDocument/diagnostic')
    eq(requests[1].params.identifier, 'compiler')
    eq(requests[2].params.identifier, 'analyzers')
end

return T
