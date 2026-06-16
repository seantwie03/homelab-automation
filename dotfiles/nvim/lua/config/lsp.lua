-- lsp
--------------------------------------------------------------------------------
-- See https://gpanders.com/blog/whats-new-in-neovim-0-11/ for a nice overview
-- of how the lsp setup works in neovim 0.11+.

-- Enable the lsp servers configured in the lsp folder.
for server, _ in pairs(require('config.lsp_servers')) do
  vim.lsp.enable(server)
end

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, {
      buffer = ev.buf,
      desc = 'Go to definition',
    })

    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, {
      buffer = ev.buf,
      desc = 'Action',
    })
    vim.keymap.set('n', '<leader>cd', vim.lsp.buf.definition, {
      buffer = ev.buf,
      desc = 'Definition',
    })
    vim.keymap.set('n', '<leader>cD', vim.lsp.buf.declaration, {
      buffer = ev.buf,
      desc = 'Declaration',
    })
    vim.keymap.set('n', '<leader>ch', vim.lsp.buf.hover, {
      buffer = ev.buf,
      desc = 'Hover',
    })
    vim.keymap.set('n', '<leader>cI', function()
      require('telescope.builtin').lsp_implementations()
    end, {
      buffer = ev.buf,
      desc = 'Implementations',
    })
    vim.keymap.set('n', '<leader>ci', function()
      require('telescope.builtin').lsp_incoming_calls()
    end, {
      buffer = ev.buf,
      desc = 'Incoming calls',
    })
    vim.keymap.set('n', '<leader>cn', vim.lsp.buf.rename, {
      buffer = ev.buf,
      desc = 'Rename',
    })
    vim.keymap.set('n', '<leader>co', function()
      require('telescope.builtin').lsp_outgoing_calls()
    end, {
      buffer = ev.buf,
      desc = 'Outgoing calls',
    })
    vim.keymap.set('n', '<leader>cr', function()
      require('telescope.builtin').lsp_references()
    end, {
      buffer = ev.buf,
      desc = 'References',
    })
    vim.keymap.set('n', '<leader>cs', function()
      require('telescope.builtin').lsp_document_symbols()
    end, {
      buffer = ev.buf,
      desc = 'Document symbols',
    })
    vim.keymap.set('n', '<leader>cS', function()
      require('telescope.builtin').lsp_dynamic_workspace_symbols()
    end, {
      buffer = ev.buf,
      desc = 'Workspace symbols',
    })
    vim.keymap.set('n', '<leader>ct', function()
      require('telescope.builtin').lsp_type_definitions()
    end, {
      buffer = ev.buf,
      desc = 'Type definition',
    })
    vim.keymap.set('n', '<leader>cx', vim.lsp.codelens.run, {
      buffer = ev.buf,
      desc = 'Lens run',
    })

    if client:supports_method('textDocument/completion') then
      vim.opt.completeopt = { 'menu', 'menuone','noinsert','fuzzy','popup' }
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
      vim.keymap.set('i', '<C-Space>', function()
        vim.lsp.completion.get()
      end)
    end
  end,
})

-- Diagnostics
vim.diagnostic.config({
  virtual_lines = false
})
