return {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
        defaults = {
            mode = { "n", "v" },
            ["<Leader>c"] = { name = "+code" },
            ["<Leader>f"] = { name = "+find" },
            ["<Leader>fg"] = { name = "+git" },
            ["<Leader>fl"] = { name = "+linux" },
            ["<Leader>fv"] = { name = "+vim" },
            ["<Leader>p"] = { name = "+paste" },
            ["<Leader>t"] = { name = "+toggle" },
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
