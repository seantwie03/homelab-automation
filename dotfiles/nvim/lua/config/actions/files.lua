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

function M.copy_project_relative_file_path()
    local path = vim.api.nvim_buf_get_name(0)

    if path == '' then
        vim.notify('Current buffer is not visiting a file', vim.log.levels.ERROR)
        return
    end

    local root = vim.fs.root(path, { '.git', '.project' })
    local copied_path = root and vim.fs.relpath(root, path) or path
    vim.fn.setreg('+', copied_path)
    vim.notify('Copied file path: ' .. copied_path)

    return copied_path
end

return M
