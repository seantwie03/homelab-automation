return {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    keys = {
        {
            "<leader>gD",
            "<Cmd>DiffviewOpen origin/HEAD...HEAD --imply-local<CR>",
            desc = "Review MR (diffview)"
        }
    }
}
