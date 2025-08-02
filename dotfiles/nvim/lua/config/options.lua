-- options
--------------------------------------------------------------------------------
-- How to check current settings:
-- :set keymodel? -- Only method with Tab completion
-- :lua=vim.o.keymodel -- This is equivalent to vim.pretty_print(vim.o.keymodel)
-- :lua=vim.opt.keymodel -- This is equivalent to vim.pretty_print(vim.opt.keymodel)
-- More information about using Lua in Neovim can be found in :h lua-guide

-- General
vim.opt.fileencoding = "utf-8"
vim.opt.fileformat = "unix"
vim.opt.shortmess:append("I")
vim.opt.nrformats:append("alpha")
vim.opt.updatetime = 250
--vim.opt.clipboard:prepend({ "unnamed", "unnamedplus" })
vim.opt.clipboard:prepend({ "unnamedplus" })
vim.opt.scrolloff = 8
vim.opt.laststatus = 3
vim.opt.swapfile = false
vim.opt.undofile = true
-- TODO: Setup backups and backupdir
vim.opt.guifont = "Iosevka Nerd Font Mono:h12"

-- Window Splits
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Indentation
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4

-- Line Breaks
vim.opt.wrap = true
vim.opt.breakindent = true
vim.opt.linebreak = true

-- Line Numbers
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"

-- Search and Substitution
-- Case insensitive searching UNLESS /C or capital in search
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.inccommand = 'split'

-- Show whitespace characters
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Mouse and Arrows
-- These options make Neovim behave more like other applications when using the mouse or "universal" movement keys
-- (Arrows, Home, and End). Using these keys are sub-optimal in Neovim, so rather than worrying about learning their
-- special Neovim behavior, just make them behave the same in Neovim as they do in other applications.
vim.opt.whichwrap = "b,s,<,>,[,]"
vim.opt.keymodel = { "startsel", "stopsel" }
vim.opt.selectmode = { "mouse", "key" }
vim.opt.mousemodel = "popup_setpos"
vim.o.mouse = "ar"
