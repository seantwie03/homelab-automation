-- keymap
--------------------------------------------------------------------------------
-- Navigate visual lines
vim.keymap.set({ 'n', 'x' }, 'j', 'gj', { desc = 'Navigate down (visual line)' })
vim.keymap.set({ 'n', 'x' }, 'k', 'gk', { desc = 'Navigate up (visual line)' })
vim.keymap.set({ 'n', 'x' }, '<Down>', 'gj', { desc = 'Navigate down (visual line)' })
vim.keymap.set({ 'n', 'x' }, '<Up>', 'gk', { desc = 'Navigate up (visual line)' })
vim.keymap.set('i', '<Down>', '<C-\\><C-o>gj', { desc = 'Navigate down (visual line)' })
vim.keymap.set('i', '<Up>', '<C-\\><C-o>gk', { desc = 'Navigate up (visual line)' })

-- Diagnostic keymaps
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Quickly source current file / execute Lua code
vim.keymap.set('n', '<leader>xx', '<Cmd>source %<CR>', { desc = 'Source current file' })
vim.keymap.set('n', '<leader>x', '<Cmd>:.lua<CR>', { desc = 'Lua: execute current line' })
vim.keymap.set('v', '<leader>x', '<Cmd>:lua<CR>', { desc = 'Lua: execute current selection' })

-- mswin.vim
-- The next several bindings are translated from mswin.vim with slight modifications.
-- These mappings make CTRL-a, CTRL-c, CTRL-s, CTRL-v, CTRL-x, etc. act more like other editors.

-- Remap original CTRL-a functionality to <Leader>
vim.keymap.set({ "n", "v" }, "<Leader><C-a>", "<C-a>", { desc = "increase alphanumeric char"})
-- Set CTRL-a to Select all in Normal and Insert modes (translated from mswin.vim)
vim.keymap.set({ "n" }, "<C-a>", "ggVG", { desc = "select all"})
vim.keymap.set({ "i" }, "<C-a>", "<C-o>gg<C-o>gH<C-o>G", { desc = "select all"})

-- Remap original CTRL-x functionality to <Leader>
vim.keymap.set({ "n", "v" }, "<Leader><C-x>", "<C-x>", { desc = "decrease alphanumeric char"})
-- Set CTRL-x to Cut in Normal and Visual modes (translated from mswin.vim)
vim.keymap.set({ "n" }, "<C-x>", "dd", { desc = "cut line"})
vim.keymap.set({ "n" }, "<S-Del>", "dd", { desc = "cut line"})
vim.keymap.set({ "v" }, "<C-x>", '"+x', { desc = "cut selection"})
vim.keymap.set({ "v" }, "<S-Del>", '"+x', { desc = "cut selection"})

-- CTRL-c and Shift-Insert are copy (transalted from mswin.vim)
vim.keymap.set({ "n" }, "<C-c>", "yy", { desc = "copy line"})
vim.keymap.set({ "v" }, "<C-c>", '"+y', { desc = "copy selection"})
vim.keymap.set({ "v" }, "<C-Insert>", '"+y', { desc = "copy selection"})

-- Ctrl-v and Shift-Insert paste
vim.keymap.set({ "v" }, "<C-v>", "P", { desc = "Paste"}) -- Does not add previously selected text to unnamed register
vim.keymap.set({ "i" }, "<C-v>", "<Cmd>set paste<CR><C-r>+<Cmd>set nopaste<CR>", { desc = "paste"})
vim.keymap.set({ "i" }, "<S-Insert>", "<Cmd>set paste<CR><C-r>+<Cmd>set nopaste<CR>", { desc = "paste"})
vim.cmd([[cnoremap <C-v> <C-r>+]])

-- Ctrl-s - Save
vim.keymap.set({ "n", "v", "i", "c" }, "<C-s>", "<Esc><Cmd>update<CR>", { desc = "return to Normal mode and save"})

-- end mswin.vim

-- 0 goes to ^ on first press then 0 on second press
-- https://www.reddit.com/r/vim/comments/uorjet/comment/i8gmxgn/?utm_source=share&utm_medium=web2x&context=3
vim.cmd([[nnoremap <expr> <silent> 0 col('.') == match(getline('.'),'\S')+1 ? '0' : '^']])

-- Y behaves like D, C, etc.
vim.keymap.set({ "n" }, "Y", "y$", { desc = "copy to end of line"})
vim.keymap.set({ "v" }, "Y", "$y", { desc = "copy to end of line"})

-- Make Backspace behave more like other applications:
-- Pressing Backspace in visual mode will delete selected text without changing the unnamed register
vim.keymap.set({ "v" }, "<Backspace>", '"_d', { desc = "delete selection"})
-- For legacy reasons, CTRL-Backspace is actually the same as CTRL-h
-- In Normal mode, CTRL-h is used for navigating between splits. This mapping is only applied to
-- insert and cmdline mode. In Normal mode, I should use daw and diw instad.
vim.keymap.set({ "i" }, "<C-h>", '<C-o>"_db', { desc = "delete word before cursor"})
vim.keymap.set({ "c" }, "<C-h>", "<C-w>", { desc = "delete word before cursor"})

-- Make Delete behave more like other applications:
-- Pressing CTRL-Delete will delete the word in front of the cursor without changing the unnamed register
vim.keymap.set({ "" }, "<C-Del>", '"_de', { desc = "delete word in front of cursor"})
vim.keymap.set({ "i" }, "<C-Del>", '<C-o>"_de', { desc = "delete word in front of cursor"})

-- Switch windows
vim.keymap.set({ "n" }, "<c-j>", "<c-w><c-j>", { desc = "move cursor to Nth window below current one"})
vim.keymap.set({ "n" }, "<c-k>", "<c-w><c-k>", { desc = "move cursor to Nth window above current one"})
vim.keymap.set({ "n" }, "<c-h>", "<c-w><c-h>", { desc = "move cursor to Nth window left of current one"})
vim.keymap.set({ "n" }, "<c-l>", "<c-w><c-l>", { desc = "move cursor to Nth window right of current one"})

-- Keep view centered while scrolling and searching
vim.keymap.set({ "n" }, "<C-d>", "<C-d>zz", { desc = "scroll half-page down"})
vim.keymap.set({ "n" }, "<C-u>", "<C-u>zz", { desc = "scroll half-page up"})
vim.keymap.set({ "n" }, "n", "nzz", { desc = "next match"})
vim.keymap.set({ "n" }, "N", "Nzz", { desc = "previous match"})
vim.keymap.set({ "n" }, "{", "{zz", { desc = "center previous paragraph"})
vim.keymap.set({ "n" }, "}", "}zz", { desc = "center next paragraph"})

-- Open new lines
-- These mappings are useful when I want to paste a character-wise selection on
-- a new line above or below the current line
vim.keymap.set({ "n", "v" }, "<Leader>O", "O<Esc>", { desc = "Open new line above"})
vim.keymap.set({ "n", "v" }, "<Leader>o", "o<Esc>", { desc = "open new line below"})
