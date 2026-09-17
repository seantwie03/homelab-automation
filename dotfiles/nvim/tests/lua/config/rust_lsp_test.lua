local config_dir = vim.fn.stdpath('config')
local config = dofile(config_dir .. '/lsp/rust_analyzer.lua')
local servers = require('config.lsp_servers')

local T = MiniTest.new_set()

T['rust-analyzer is installed and configured for Rust projects'] = function()
    MiniTest.expect.equality(servers.rust_analyzer, 'rust-analyzer')
    MiniTest.expect.equality(config.cmd, { 'rust-analyzer' })
    MiniTest.expect.equality(config.filetypes, { 'rust' })
    MiniTest.expect.equality(
        config.root_markers,
        { 'Cargo.toml', 'rust-project.json', '.git' }
    )
end

return T
