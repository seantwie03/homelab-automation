return {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
        spec = {
            { "<Leader>c", group = "code" },
            { "<Leader>f", group = "files" },
            { "<Leader>p", group = "paste" },
            { "<Leader>t", group = "toggle" },
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
