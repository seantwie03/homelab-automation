local M = {}

local function listed_loaded_buffers()
    return vim.tbl_filter(function(buffer)
        return vim.api.nvim_buf_is_loaded(buffer)
            and vim.bo[buffer].buflisted
    end, vim.api.nvim_list_bufs())
end

local function display_name(buffer)
    local name = vim.api.nvim_buf_get_name(buffer)
    if name == '' then
        return '[No Name]'
    end

    return vim.fn.fnamemodify(name, ':~:.')
end

local function buffer_name(buffer)
    local name = vim.api.nvim_buf_get_name(buffer)
    return name ~= '' and name or '[No Name]'
end

local function open_picker(title, entries)
    local telescope_config = require('telescope.config').values

    require('telescope.pickers').new({}, {
        finder = require('telescope.finders').new_table({
            entry_maker = function(entry)
                return entry
            end,
            results = entries,
        }),
        previewer = telescope_config.grep_previewer({}),
        prompt_title = title,
        sorter = telescope_config.generic_sorter({}),
    }):find()
end

function M.collect_open_buffer_lines()
    local entries = {}

    for _, buffer in ipairs(listed_loaded_buffers()) do
        local name = display_name(buffer)
        for line_number, line in ipairs(vim.api.nvim_buf_get_lines(buffer, 0, -1, false)) do
            table.insert(entries, {
                bufnr = buffer,
                col = 1,
                display = string.format('%s:%d  %s', name, line_number, line),
                filename = buffer_name(buffer),
                lnum = line_number,
                ordinal = string.format('%s %s', name, line),
                text = line,
            })
        end
    end

    return entries
end

function M.search_open_buffers()
    open_picker('Search open buffers', M.collect_open_buffer_lines())
end

return M
