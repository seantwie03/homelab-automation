return {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.8',
    dependencies = {
        "nvim-lua/plenary.nvim",
        {
            "nvim-telescope/telescope-fzf-native.nvim",
            build = "make",
            cond = function()
                return vim.fn.executable("make") == 1
            end,
        },
    },
    keys = {
        -- Search vim things (Marks, Registers, Ex command history, Current Buffer, etc.)
        -- I am not putting these behind the <Leader>f for two reasons:
        -- - One, these key combinations are pretty obscure and not likely to cause conflicts
        -- - Two, they feel like powered up version of what vim capabilities
        --     - For example '/' is regular vim buffer search, <Leader>/ is doing the same thing, but with Telescope
        --     - If these cause a conflict I could move these under <Leader>fv* ([F]ind [V]im)
        {
            "<Leader>/",
            "<Cmd>Telescope current_buffer_fuzzy_find<CR>",
            desc = "Telescope current_buffer_fuzzy_find",
        },
        {
            "<Leader>,",
            "<Cmd>Telescope buffers show_all_buffers=true<CR>",
            desc = "Telescope buffers show_all_buffers=true",
        },
        { "<Leader>:",  "<Cmd>Telescope command_history<CR>",     desc = "Telescope command_history" },
        { '<Leader>"',  "<Cmd>Telescope registers<CR>",           desc = "Telescope registers" },
        { "<Leader>`",  "<Cmd>Telescope marks<CR>",               desc = "Telescope marks" },
        -- [F]ind stuff
        { "<Leader>fb", "<Cmd>Telescope buffers<CR>",             desc = "Telescope buffers" },
        { "<Leader>fd", "<Cmd>Telescope diagnostics bufnr=0<CR>", desc = "Telescope diagnostics bufnr=0" },
        {
            "<Leader>fD",
            "<Cmd>Telescope diagnostics<CR>",
            desc = "Telescope diagnostics (workspace)",
        },
        { "<Leader>ff", "<Cmd>Telescope find_files<CR>", desc = "Telescope find_files" },
        { "<Leader>fr", "<Cmd>Telescope oldfiles<CR>",   desc = "Telescope oldfiles (recent)" },
        { "<Leader>fR", "<Cmd>Telescope resume<CR>",     desc = "Telescope resume" },
        { "<Leader>ft", "<Cmd>Telescope live_grep<CR>",  desc = "Telescope live_grep (text)" },
        {
            "<Leader>fs",
            function()
                require("telescope.builtin").lsp_document_symbols({
                    symbols = {
                        "Class",
                        "Function",
                        "Method",
                        "Constructor",
                        "Interface",
                        "Module",
                        "Struct",
                        "Trait",
                        "Field",
                        "Property",
                    },
                })
            end,
            desc = "Telescope lsp_document_symbols",
        },
        {
            "<Leader>fS",
            function()
                require("telescope.builtin").lsp_dynamic_workspace_symbols({
                    symbols = {
                        "Class",
                        "Function",
                        "Method",
                        "Constructor",
                        "Interface",
                        "Module",
                        "Struct",
                        "Trait",
                        "Field",
                        "Property",
                    },
                })
            end,
            desc = "Telescope lsp_dynamic_workspace_symbols",
        },
        -- [F]ind [G]it stuff
        { "<Leader>fgc", "<Cmd>Telescope git_commits<CR>",  desc = "Telescope git_commits" },
        { "<Leader>fgs", "<Cmd>Telescope git_status<CR>",   desc = "Telescope git_status" },
        -- [F]ind [L]inux stuff
        { "<Leader>flm", "<Cmd>Telescope man_pages<CR>",    desc = "Telescope man pages" },
        -- [F]ind [V]im stuff
        { "<Leader>fva", "<Cmd>Telescope autocommands<CR>", desc = "Telescope autocommands" },
        { "<Leader>fvc", "<Cmd>Telescope commands<CR>",     desc = "Telescope commands" },
        { "<Leader>fvC", "<Cmd>Telescope highlights<CR>",   desc = "Telescope highlights (colors)" },
        { "<Leader>fvh", "<Cmd>Telescope help_tags<CR>",    desc = "Telescope help_tags" },
        { "<Leader>fvk", "<Cmd>Telescope keymaps<CR>",      desc = "Telescope keymaps" },
        { "<Leader>fvo", "<Cmd>Telescope vim_options<CR>",  desc = "Telescope vim_options" },
        {
            "<Leader>fvs",
            function()
                require("telescope.builtin").find_files({ cwd = "~/.config/nvim" })
            end,
            desc = "Find vim settings",
        },
    },
    opts = {
        defaults = {
            prompt_prefix = "🔎 ",
            selection_caret = " ",
            mappings = {
                i = {
                    --   ['<Esc>'] = 'close',
                    ["<C-Down>"] = function(...)
                        return require("telescope.actions").cycle_history_next(...)
                    end,
                    ["<C-Up>"] = function(...)
                        return require("telescope.actions").cycle_history_prev(...)
                    end,
                    ["<C-f>"] = function(...)
                        return require("telescope.actions").preview_scrolling_down(...)
                    end,
                    ["<C-b>"] = function(...)
                        return require("telescope.actions").preview_scrolling_up(...)
                    end,
                },
                n = {
                    ["q"] = function(...)
                        return require("telescope.actions").close(...)
                    end,
                },
            },
        },
    },
    config = function(_, opts)
        pcall(require("telescope").load_extension, "fzf")
        require("telescope").setup(opts)
    end,
}
