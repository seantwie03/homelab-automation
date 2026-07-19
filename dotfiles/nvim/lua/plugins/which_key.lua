return {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
        spec = {
            { "<Leader>b", group = "buffers" },
            { "<Leader>c", group = "code" },
            { "<Leader>f", group = "files" },
            { "<Leader>h", group = "help" },
            { "<Leader>i", group = "insert" },
            { "<Leader>s", group = "search" },
            { "<Leader>t", group = "toggle" },
            { "<Leader>w", group = "windows" },
        },
    },
    keys = {
        {
            "<leader>?",
            function()
                require("which-key").show({ global = false })
            end,
            desc = "Buffer Local Keymaps (which-key)",
        },
    },
}
