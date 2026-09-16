local eq = MiniTest.expect.equality
-- Unit tests call helpers directly, bypassing lazy key/command triggers.
require('lazy').load({ plugins = { 'vim-table-mode' } })
local actions = require('config.actions.markdown_tables')
local original_buffer
local buffer
local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            original_buffer = vim.api.nvim_get_current_buf()
            buffer = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_set_current_buf(buffer)
            vim.bo.filetype = 'markdown'
        end,
        post_case = function()
            vim.api.nvim_set_current_buf(original_buffer)
            vim.api.nvim_buf_delete(buffer, { force = true })
        end,
    },
})

T['insert row above preserves widths and selects first cell'] = function()
    local line = '| name | count |'
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { line })
    actions.insert_row()
    eq(vim.api.nvim_buf_get_lines(0, 0, -1, false), { '|      |       |', line })
    eq(vim.api.nvim_win_get_cursor(0), { 1, 2 })
end

T['insert row preserves indentation and escaped pipes'] = function()
    local line = '  | a\\|b | 界 |'
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { line })
    actions.insert_row()
    eq(vim.api.nvim_buf_get_lines(0, 0, -1, false), { '  |      |    |', line })
    eq(vim.api.nvim_win_get_cursor(0), { 1, 4 })
end

T['insert row at separator creates cells, not another separator'] = function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { '|:----|----:|' })
    actions.insert_row()
    eq(vim.api.nvim_get_current_line(), '|     |     |')
end

T['insert row outside table does nothing'] = function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'A paragraph.' })
    actions.insert_row()
    eq(vim.api.nvim_buf_get_lines(0, 0, -1, false), { 'A paragraph.' })
end

T['align accepts spaced separators and matches Emacs left and right columns'] = function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        '| Name | Qty |', '| :--- | ---: |', '| x | 12 |', '| longer | 3 |',
    })
    vim.api.nvim_win_set_cursor(0, { 3, 6 })
    actions.align()
    local expected = {
        '| Name   | Qty |', '|:-------|----:|', '| x      |  12 |', '| longer |   3 |',
    }
    eq(vim.api.nvim_buf_get_lines(0, 0, -1, false), expected)
    eq(vim.api.nvim_win_get_cursor(0), { 3, 11 })
    actions.align()
    eq(vim.api.nvim_buf_get_lines(0, 0, -1, false), expected)
end

T['align only changes the current table'] = function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        '| A | B |', '| --- | --- |', '| x | yy |', '', '| untouched|table |',
    })
    actions.align()
    eq(vim.api.nvim_buf_get_lines(0, 3, -1, false), { '', '| untouched|table |' })
end

T['align outside table does nothing'] = function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'A paragraph.' })
    actions.align()
    eq(vim.api.nvim_buf_get_lines(0, 0, -1, false), { 'A paragraph.' })
end

return T
