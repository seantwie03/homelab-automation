local project = require('config.project')
local eq = MiniTest.expect.equality
local new_set = MiniTest.new_set

local original_buffer
local original_cwd
local original_root
local test_buffer

local T = new_set({
    hooks = {
        pre_case = function()
            original_buffer = vim.api.nvim_get_current_buf()
            original_cwd = vim.uv.cwd
            original_root = vim.fs.root
            test_buffer = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_set_current_buf(test_buffer)
        end,
        post_case = function()
            vim.uv.cwd = original_cwd
            vim.fs.root = original_root

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

T['find_root()'] = new_set()

T['find_root()']['uses the configured project markers'] = function()
    local received
    vim.fs.root = function(...)
        received = { ... }
        return '/tmp/project'
    end

    local root = project.find_root('/tmp/project/src/main.lua')

    eq(root, '/tmp/project')
    eq(received, {
        '/tmp/project/src/main.lua',
        { '.git', '.project' },
    })
end

T['current_root()'] = new_set()

T['current_root()']['finds the project associated with the current file'] = function()
    vim.api.nvim_buf_set_name(test_buffer, '/tmp/project/src/main.lua')
    vim.uv.cwd = function()
        return '/tmp/other'
    end
    vim.fs.root = function(path)
        eq(path, '/tmp/project/src/main.lua')
        return '/tmp/project'
    end

    eq(project.current_root(), '/tmp/project')
end

T['current_root()']['finds a project from the cwd for an unnamed buffer'] = function()
    vim.uv.cwd = function()
        return '/tmp/project/src'
    end
    vim.fs.root = function(path)
        eq(path, '/tmp/project/src')
        return '/tmp/project'
    end

    eq(project.current_root(), '/tmp/project')
end

T['current_root()']['falls back to the cwd outside a project'] = function()
    vim.api.nvim_buf_set_name(test_buffer, '/tmp/notes/todo.md')
    vim.uv.cwd = function()
        return '/tmp/fallback'
    end
    vim.fs.root = function()
        return nil
    end

    eq(project.current_root(), '/tmp/fallback')
end

return T
