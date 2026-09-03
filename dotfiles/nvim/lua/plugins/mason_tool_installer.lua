local servers = require("config.lsp_servers")
local tools = vim.tbl_values(servers)
table.insert(tools, "rassumfrassum")
table.sort(tools)

return {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = {
        "mason-org/mason.nvim",
    },
    opts = {
        ensure_installed = tools,
    },
}
