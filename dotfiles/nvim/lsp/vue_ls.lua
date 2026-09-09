---@brief
---
--- The official Vue language server. In hybrid mode it handles Vue template,
--- CSS, and semantic-token features while ts_ls supplies TypeScript support.

---@type vim.lsp.Config
return {
    cmd = { 'vue-language-server', '--stdio' },
    filetypes = { 'vue' },
    root_markers = { 'package.json' },
    on_init = function(client)
        local retries = 0

        local function typescript_handler(_, result, context)
            local ts_client = vim.lsp.get_clients({
                bufnr = context.bufnr,
                name = 'ts_ls',
            })[1]

            if not ts_client then
                if retries <= 10 then
                    retries = retries + 1
                    vim.defer_fn(function()
                        typescript_handler(_, result, context)
                    end, 100)
                else
                    vim.notify(
                        'Could not find ts_ls client required by vue_ls.',
                        vim.log.levels.ERROR
                    )
                end
                return
            end

            local param = unpack(result)
            local id, command, payload = unpack(param)
            ts_client:exec_cmd({
                title = 'vue_request_forward',
                command = 'typescript.tsserverRequest',
                arguments = { command, payload },
            }, { bufnr = context.bufnr }, function(_, response)
                local response_data = { { id, response and response.body } }
                client:notify('tsserver/response', response_data)
            end)
        end

        client.handlers['tsserver/request'] = typescript_handler
    end,
}
