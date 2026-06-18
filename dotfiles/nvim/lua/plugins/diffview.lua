return {
    "dlyongemallo/diffview-plus.nvim",
    cmd = {
        "DiffviewOpen",
        "DiffviewToggle",
        "DiffviewFileHistory",
        "DiffviewDiffFiles",
        "DiffviewLog",
    },
    opts = {
        enhanced_diff_hl = true,
        diffopt = {
            algorithm = "histogram",
            linematch = 60,
        },
        file_panel = {
            listing_style = "tree",
            win_config = { position = "left", width = "auto" },
        },
    },
    keys = {
        {
            "<leader>gd",
            "<Cmd>DiffviewOpen<CR>",
            desc = "DiffviewOpen"
        },
        {
            "<leader>gD",
            "<Cmd>DiffviewOpen origin/HEAD...HEAD --imply-local<CR>",
            desc = "Review MR (checkout MR branch first)"
        }
    }
}
