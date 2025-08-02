return {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {
        sections = {
            lualine_c = { { "filename", path = 1, symbols = { modified = "  " } } },
            lualine_x = { "encoding", "fileformat", { "filetype", colored = false } },
        },
    }
}
