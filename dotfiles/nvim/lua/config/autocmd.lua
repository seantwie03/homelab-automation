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
