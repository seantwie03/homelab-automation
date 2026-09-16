return {
    'dhruvasagar/vim-table-mode',
    -- Keys and commands load the plugin without replaying FileType handlers.
    cmd = { 'TableModeRealign', 'TableSort' },
    init = function()
        -- Tableize has a separate mapping switch from the other defaults.
        vim.g.table_mode_disable_mappings = 1
        vim.g.table_mode_disable_tableize_mappings = 1
        vim.g.table_mode_always_active = 0
        vim.g.table_mode_auto_align = 0
        vim.g.table_mode_syntax = 0
        vim.g.table_mode_verbose = 0
        vim.g.table_mode_corner = '|'
        vim.g.table_mode_corner_corner = '|'
        vim.g.table_mode_separator = '|'
        vim.g.table_mode_fillchar = '-'
        vim.g.table_mode_header_fillchar = '-'
        vim.g.table_mode_align_char = ':'
        vim.g.table_mode_ignore_align = 0
    end,
    keys = {
        {
            '<localleader>ba',
            function() require('config.actions.markdown_tables').align() end,
            ft = 'markdown',
            desc = 'Align table',
        },
        {
            '<localleader>bdr',
            '<Cmd>call tablemode#spreadsheet#DeleteRow()<CR>',
            ft = 'markdown',
            desc = 'Delete row',
        },
        {
            '<localleader>bdc',
            '<Cmd>call tablemode#spreadsheet#DeleteColumn()<CR>',
            ft = 'markdown',
            desc = 'Delete column',
        },
        {
            '<localleader>bic',
            '<Cmd>call tablemode#spreadsheet#InsertColumn(0)<CR><Cmd>stopinsert<CR>',
            ft = 'markdown',
            desc = 'Insert column before',
        },
        {
            '<localleader>bir',
            function() require('config.actions.markdown_tables').insert_row() end,
            ft = 'markdown',
            desc = 'Insert row above',
        },
        { '<localleader>bs', '<Cmd>TableSort<CR>', ft = 'markdown', desc = 'Sort table' },
    },
}
