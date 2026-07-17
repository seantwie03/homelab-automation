local M = {}

local markers = { '.git', '.project' }

function M.find_root(path)
    return vim.fs.root(path, markers)
end

function M.current_root()
    local buffer_path = vim.api.nvim_buf_get_name(0)
    local cwd = assert(vim.uv.cwd(), 'Could not determine the current working directory')
    local start_path = buffer_path ~= '' and buffer_path or cwd

    return M.find_root(start_path) or cwd
end

return M
