local file_actions = require('config.actions.files')
local project = require('config.project')
local eq = MiniTest.expect.equality
local new_set = MiniTest.new_set

local original_buffer
local original_notify
local original_find_root
local original_setreg
local notifications
local registers
local test_buffer

local T = new_set({
    hooks = {
        pre_case = function()
            original_buffer = vim.api.nvim_get_current_buf()
            test_buffer = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_set_current_buf(test_buffer)

            notifications = {}
            registers = {}
            original_notify = vim.notify
            original_find_root = project.find_root
            original_setreg = vim.fn.setreg

            vim.notify = function(...)
                table.insert(notifications, { ... })
            end
            vim.fn.setreg = function(...)
                table.insert(registers, { ... })
            end
        end,
        post_case = function()
            vim.notify = original_notify
            project.find_root = original_find_root
            vim.fn.setreg = original_setreg

            if vim.api.nvim_buf_is_valid(original_buffer) then
                vim.api.nvim_set_current_buf(original_buffer)
            else
                vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))
            end

            if vim.api.nvim_buf_is_valid(test_buffer) then
                vim.api.nvim_buf_delete(test_buffer, { force = true })
            end
        end,
    },
})

T['copy_file_name()'] = new_set()

T['copy_file_name()']['copies only the current file name'] = function()
    vim.api.nvim_buf_set_name(test_buffer, '/tmp/project/archive.tar.gz')

    local name = file_actions.copy_file_name()

    eq(name, 'archive.tar.gz')
    eq(registers, { { '+', 'archive.tar.gz' } })
    eq(notifications, { { 'Copied file name: archive.tar.gz' } })
end

T['copy_file_name()']['reports an error for a buffer without a file'] = function()
    local name = file_actions.copy_file_name()

    eq(name, nil)
    eq(registers, {})
    eq(notifications, {
        { 'Current buffer is not visiting a file', vim.log.levels.ERROR },
    })
end

T['copy_project_relative_file_path()'] = new_set()

T['copy_project_relative_file_path()']['copies a path relative to the project root'] = function()
    vim.api.nvim_buf_set_name(test_buffer, '/tmp/project/src/main.lua')
    project.find_root = function()
        return '/tmp/project'
    end

    local path = file_actions.copy_project_relative_file_path()

    eq(path, 'src/main.lua')
    eq(registers, { { '+', 'src/main.lua' } })
    eq(notifications, { { 'Copied file path: src/main.lua' } })
end

T['copy_project_relative_file_path()']['copies the absolute path outside a project'] = function()
    vim.api.nvim_buf_set_name(test_buffer, '/tmp/notes/todo.md')
    project.find_root = function()
        return nil
    end

    local path = file_actions.copy_project_relative_file_path()

    eq(path, '/tmp/notes/todo.md')
    eq(registers, { { '+', '/tmp/notes/todo.md' } })
    eq(notifications, { { 'Copied file path: /tmp/notes/todo.md' } })
end

T['copy_project_relative_file_path()']['reports an error for a buffer without a file'] = function()
    local path = file_actions.copy_project_relative_file_path()

    eq(path, nil)
    eq(registers, {})
    eq(notifications, {
        { 'Current buffer is not visiting a file', vim.log.levels.ERROR },
    })
end

return T
