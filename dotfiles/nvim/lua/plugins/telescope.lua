local function locate_with_telescope()
    local config = require("telescope.config").values
    local finders = require("telescope.finders")
    local make_entry = require("telescope.make_entry")
    local options = {
        cwd = "/",
        path_display = { "absolute" },
    }

    require("telescope.pickers").new(options, {
        finder = finders.new_job(function(prompt)
            if prompt == "" then
                return nil
            end

            return {
                "locate",
                "--existing",
                "--ignore-case",
                "--limit",
                "1000",
                prompt,
            }
        end, make_entry.gen_from_file(options), 1000, "/"),
        previewer = config.file_previewer(options),
        prompt_title = "Locate files (Telescope)",
        sorter = config.file_sorter(options),
    }):find()
end

return {
    'nvim-telescope/telescope.nvim',
    -- version = '*',
    branch = "master",
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
            function()
                require("telescope.builtin").buffers({ cwd_only = true })
            end,
            desc = "Find project buffers",
        },
        { "<Leader>.",  "<Cmd>Telescope find_files<CR>",          desc = "Find project files" },
        { "<Leader>:",  "<Cmd>Telescope commands<CR>",            desc = "Telescope commands" },
        { '<Leader>"',  "<Cmd>Telescope registers<CR>",           desc = "Telescope registers" },
        { "<Leader>`",  "<Cmd>Telescope marks<CR>",               desc = "Telescope marks" },
        -- File actions
        { "<Leader>ff", locate_with_telescope, desc = "Locate file with Telescope" },
        { "<Leader>fr", "<Cmd>Telescope oldfiles<CR>", desc = "Find recent files" },
    },
    opts = {
        defaults = {
            layout_strategy = "flex",
            layout_config = {
                flex = {
                    flip_columns = 150,
                },
            },
            prompt_prefix = "🔎 ",
            selection_caret = " ",
            mappings = {
                i = {
                    --   ['<Esc>'] = 'close',
                    ["<C-Down>"] = function(...) require("telescope.actions").cycle_history_next(...) end,
                    ["<C-Up>"] = function (...) require("telescope.actions").cycle_history_prev(...) end,
                },
                n = {
                    ["q"] = function(...) return require("telescope.actions").close(...) end,
                },
            },
        },
    },
    config = function(_, opts)
        require("telescope").setup(opts)
        pcall(require("telescope").load_extension, "fzf")
    end,
}
