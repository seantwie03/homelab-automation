return {
    "esmuellert/codediff.nvim",
    cmd = "CodeDiff",
    opts = {},
    keys = {
        {
            "<leader>gd",
            "<Cmd>CodeDiff<CR>",
            desc = "Git diff",
        },
        {
            "<leader>gD",
            "<Cmd>CodeDiff origin/main...HEAD<CR>",
            desc = "Git diff against origin/main",
        },
    },
}
