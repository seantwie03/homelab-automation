return {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    opts = {
        install_dir = vim.fn.stdpath("data") .. "/site",
    },
    config = function(_, opts)
        require("nvim-treesitter").setup(opts)
        require("nvim-treesitter").install("all")

        vim.api.nvim_create_autocmd("FileType", {
            pattern = "all",
            callback = function()
                pcall(vim.treesitter.start)
            end,
        })
    end,
}
