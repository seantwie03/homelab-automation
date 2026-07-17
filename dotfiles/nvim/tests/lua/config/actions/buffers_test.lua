local buffer_actions = require('config.actions.buffers')
local eq = MiniTest.expect.equality
local new_set = MiniTest.new_set

local original_buffer
local test_buffer

local T = new_set({
    hooks = {
        pre_case = function()
            original_buffer = vim.api.nvim_get_current_buf()
            test_buffer = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_set_current_buf(test_buffer)
        end,
        post_case = function()
            if vim.api.nvim_buf_is_valid(original_buffer) then
                vim.api.nvim_set_current_buf(original_buffer)
            else
                vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))
            end

            for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
                local name = vim.api.nvim_buf_get_name(buffer)
                if buffer == test_buffer or name:match('%[Scratch%]$') then
                    vim.api.nvim_buf_delete(buffer, { force = true })
                end
            end
        end,
    },
})

T['open_scratch_buffer()'] = new_set()

T['open_scratch_buffer()']['creates and selects a scratch buffer'] = function()
    buffer_actions.open_scratch_buffer()

    eq(vim.api.nvim_buf_get_name(0), vim.fs.joinpath(vim.uv.os_tmpdir(), '[Scratch]'))
    eq(vim.bo.buftype, 'nofile')
end

T['open_scratch_buffer()']['reuses the existing scratch buffer'] = function()
    buffer_actions.open_scratch_buffer()
    local scratch_buffer = vim.api.nvim_get_current_buf()

    vim.api.nvim_set_current_buf(test_buffer)
    buffer_actions.open_scratch_buffer()

    eq(vim.api.nvim_get_current_buf(), scratch_buffer)
end

return T
