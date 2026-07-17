return {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    opts = {
        install_dir = vim.fn.stdpath("data") .. "/site",
    },
    config = function(_, opts)
        require("nvim-treesitter").setup(opts)

        -- Headless tests exit before asynchronous installs finish, causing every run to download parsers again.
        if #vim.api.nvim_list_uis() > 0 then
            require("nvim-treesitter").install("all")
        end

        vim.api.nvim_create_autocmd("FileType", {
            pattern = "all",
            callback = function()
                pcall(vim.treesitter.start)
            end,
        })
    end,
}
