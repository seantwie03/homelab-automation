local M = {}

-- vim-table-mode only recognizes separator rows without spaces inside them.
-- markdown-mode accepts both forms, so normalize these before realigning.
function M.align()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local first, last = cursor[1], cursor[1]
    if vim.fn['tablemode#table#IsTable'](first) == 0 then
        return
    end
    local before_cursor = vim.api.nvim_get_current_line():sub(1, cursor[2] + 1)
    local before_parts = vim.fn['tablemode#align#Split'](before_cursor, vim.g.table_mode_escaped_separator_regex)
    local column = math.max(1, math.floor(#before_parts / 2))
    while first > 1 and vim.fn['tablemode#table#IsTable'](first - 1) == 1 do
        first = first - 1
    end
    while last < vim.api.nvim_buf_line_count(0) and vim.fn['tablemode#table#IsTable'](last + 1) == 1 do
        last = last + 1
    end
    local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
    local changed = false
    for index, line in ipairs(lines) do
        local indent, separator = line:match('^(%s*)(|[%s:%-|]+|)%s*$')
        if separator and separator:find('-', 1, true) then
            lines[index] = indent .. separator:gsub('%s', '')
            changed = changed or lines[index] ~= line
        end
    end
    if changed then
        vim.api.nvim_buf_set_lines(0, first - 1, last, false, lines)
    end
    vim.cmd.TableModeRealign()
    -- Restore the logical cell, since wider preceding columns move it.
    local parts = vim.fn['tablemode#align#Split'](
        vim.api.nvim_buf_get_lines(0, cursor[1] - 1, cursor[1], false)[1],
        vim.g.table_mode_escaped_separator_regex
    )
    local offset = 0
    for index = 1, math.min(column * 2, #parts) do
        offset = offset + #parts[index]
    end
    vim.api.nvim_win_set_cursor(0, { cursor[1], offset + 1 })
end

-- Like markdown-table-insert-row, preserve column widths and insert above.
function M.insert_row()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    if vim.fn['tablemode#table#IsTable'](row) == 0 then
        return
    end

    local line = vim.api.nvim_get_current_line()
    local parts = vim.fn['tablemode#align#Split'](line, vim.g.table_mode_escaped_separator_regex)
    -- Split alternates cell text and delimiters; retain the indentation.
    for index = 3, #parts, 2 do
        parts[index] = string.rep(' ', vim.fn.strdisplaywidth(parts[index]))
    end
    local blank = table.concat(parts):gsub('%s+$', '')
    vim.api.nvim_buf_set_lines(0, row - 1, row - 1, false, { blank })
    local first_pipe = blank:find('|', 1, true)
    vim.api.nvim_win_set_cursor(0, { row, first_pipe + 1 })
end

return M
