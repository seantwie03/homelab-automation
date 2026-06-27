if vim.filetype then
    vim.filetype.add({
        pattern = {
            [".*/.*%.ya?ml%.j2"] = "yaml",
        },
    })
else
    vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
        pattern = {
            "*.yml.j2",
            "*.yaml.j2",
        },
        callback = function()
            vim.bo.filetype = "yaml"
        end,
    })
end
