local M = {}

function M.open_scratch_buffer()
    local name = '[Scratch]'
    local buffer = vim.fn.bufnr(name)

    if buffer == -1 then
        buffer = vim.api.nvim_create_buf(true, true)
        vim.api.nvim_buf_set_name(buffer, name)
    end

    vim.api.nvim_set_current_buf(buffer)
end

return M
