local M = {}

function M.copy_file_name()
    local path = vim.api.nvim_buf_get_name(0)

    if path == '' then
        vim.notify('Current buffer is not visiting a file', vim.log.levels.ERROR)
        return
    end

    local name = vim.fs.basename(path)
    vim.fn.setreg('+', name)
    vim.notify('Copied file name: ' .. name)

    return name
end

return M
