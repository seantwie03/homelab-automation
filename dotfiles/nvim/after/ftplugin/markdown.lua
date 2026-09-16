vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4

require('which-key').add({
    { '<localleader>b', group = 'tables', buffer = true },
    { '<localleader>bd', group = 'delete', buffer = true },
    { '<localleader>bi', group = 'insert', buffer = true },
})
