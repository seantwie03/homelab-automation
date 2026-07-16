require('lazy').load({ plugins = { 'mini.test' } })

local MiniTest = require('mini.test')
local config_dir = vim.fn.stdpath('config')

MiniTest.setup({
    collect = {
        find_files = function()
            return vim.fn.globpath(
                config_dir .. '/tests/lua',
                '**/*_test.lua',
                true,
                true
            )
        end,
    },
})

MiniTest.run()
