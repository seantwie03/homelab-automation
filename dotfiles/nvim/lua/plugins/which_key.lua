return {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
        defaults = {
            mode = { "n", "v" },
            ["<Leader>f"] = { name = "+find" },
            ["<Leader>fg"] = { name = "+git" },
            ["<Leader>fl"] = { name = "+linux" },
            ["<Leader>fv"] = { name = "+vim" },
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
