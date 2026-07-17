local search_actions = require('config.actions.search')
local eq = MiniTest.expect.equality
local new_set = MiniTest.new_set

local original_buffer
local test_buffers

local T = new_set({
    hooks = {
        pre_case = function()
            original_buffer = vim.api.nvim_get_current_buf()
            test_buffers = {}
        end,
        post_case = function()
            if vim.api.nvim_buf_is_valid(original_buffer) then
                vim.api.nvim_set_current_buf(original_buffer)
            else
                vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))
            end

            for _, buffer in ipairs(test_buffers) do
                if vim.api.nvim_buf_is_valid(buffer) then
                    vim.api.nvim_buf_delete(buffer, { force = true })
                end
            end
        end,
    },
})

local function create_buffer(name, lines)
    local buffer = vim.api.nvim_create_buf(true, false)
    table.insert(test_buffers, buffer)
    vim.api.nvim_buf_set_name(buffer, name)
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
    return buffer
end

T['collect_open_buffer_lines()'] = new_set()

T['collect_open_buffer_lines()']['collects current contents from listed buffers'] = function()
    local buffer = create_buffer('/tmp/search-lines.lua', { 'local alpha = 1', 'return alpha' })

    local matching = vim.tbl_filter(function(entry)
        return entry.bufnr == buffer
    end, search_actions.collect_open_buffer_lines())

    eq(#matching, 2)
    eq(matching[1].filename, '/tmp/search-lines.lua')
    eq(matching[1].lnum, 1)
    eq(matching[1].text, 'local alpha = 1')
    eq(matching[2].lnum, 2)
    eq(matching[2].text, 'return alpha')
end

return T
