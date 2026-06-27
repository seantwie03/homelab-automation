-- autocmd
--------------------------------------------------------------------------------
-- Highlight when yanking
vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
    callback = function()
        vim.highlight.on_yank()
    end,
})

-- Only highlight search results while searching
vim.opt.hlsearch = false
local neovimrc_inc_search_highlight = vim.api.nvim_create_augroup("NeovimrcIncSearchHighlight", { clear = true })
vim.api.nvim_create_autocmd({ "CmdlineEnter" }, {
    group = neovimrc_inc_search_highlight,
    pattern = "/,\\?",
    command = "set hlsearch",
})
vim.api.nvim_create_autocmd({ "CmdlineLeave" }, {
    group = neovimrc_inc_search_highlight,
    pattern = "/,\\?",
    command = "set nohlsearch",
})

-- Return cursor to its last position when opening a file
local neovimrc_last_cursor_position = vim.api.nvim_create_augroup("NeovimrcLastCursorPosition", { clear = true })
vim.api.nvim_create_autocmd({"BufWinEnter"}, {
    group = neovimrc_last_cursor_position,
    desc = "Return cursor to its last position when opening a file",
    pattern = "*",
    command = "silent! normal! g`\"zv",
})

-- Match .editorconfig before writing files.
local neovimrc_trim_trailing_whitespace = vim.api.nvim_create_augroup("NeovimrcTrimTrailingWhitespace", { clear = true })
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    group = neovimrc_trim_trailing_whitespace,
    pattern = "*",
    callback = function()
        if not vim.bo.modifiable or vim.bo.binary then
            return
        end

        vim.bo.endofline = true
        vim.bo.fixendofline = true

        local view = vim.fn.winsaveview()
        vim.cmd([[%s/\s\+$//e]])
        vim.fn.winrestview(view)
    end,
})
