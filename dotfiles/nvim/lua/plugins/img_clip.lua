return {
    "HakonHarnes/img-clip.nvim",
    event = "VeryLazy",
    opts = {
        default = {
            dir_path = "assets",
            relative_to_current_file = true,
            file_name = "%Y-%m-%d-%H-%M-%S",
            insert_mode_after_paste = false,
        },
        filetypes = {
            markdown = {
                template = "![]($FILE_PATH)",
            },
        },
    },
    keys = {
        { "<Leader>pi", "<Cmd>PasteImage<CR>", desc = "PasteImage" },
    },
}
