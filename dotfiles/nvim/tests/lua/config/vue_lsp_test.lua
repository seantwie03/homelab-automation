local config_dir = vim.fn.stdpath('config')
local ts_config = dofile(config_dir .. '/lsp/ts_ls.lua')
local vue_config = dofile(config_dir .. '/lsp/vue_ls.lua')

local T = MiniTest.new_set()

T['ts_ls loads the Vue TypeScript plugin'] = function()
    local plugin = ts_config.init_options.plugins[1]

    MiniTest.expect.equality(vim.tbl_contains(ts_config.filetypes, 'vue'), true)
    MiniTest.expect.equality(plugin.name, '@vue/typescript-plugin')
    MiniTest.expect.equality(plugin.languages, { 'vue' })
    MiniTest.expect.equality(
        plugin.location,
        vim.fs.joinpath(
            vim.fn.stdpath('data'),
            'mason/packages/vue-language-server/node_modules/@vue/language-server'
        )
    )
end

T['vue_ls uses the Vue language server for Vue files'] = function()
    MiniTest.expect.equality(vue_config.cmd, { 'vue-language-server', '--stdio' })
    MiniTest.expect.equality(vue_config.filetypes, { 'vue' })
    MiniTest.expect.equality(vue_config.root_markers, { 'package.json' })
end

return T
