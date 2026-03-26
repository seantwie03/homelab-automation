return {
    "HakonHarnes/img-clip.nvim",
    event = "VeryLazy",
    opts = {
        default = {
            dir_path = "assets",
            relative_to_current_file = true,
            file_name = "%Y-%m-%d-%H-%M-%S",
            insert_mode_after_paste = false,
        },
        filetypes = {
            markdown = {
                template = "![]($FILE_PATH)",
            },
        },
    },
    keys = {
        { "<Leader>pi", "<Cmd>PasteImage<CR>", desc = "PasteImage" },
        { "<Leader>v",  "<Cmd>PasteImage<CR>", desc = "PasteImage" },
        {
            "<Leader>fi",
            function()
                local telescope = require("telescope.builtin")
                local actions = require("telescope.actions")
                local action_state = require("telescope.actions.state")

                telescope.find_files({
                    find_command = { "fd", "--type", "f", "-e", "png", "-e", "jpg", "-e", "jpeg", "-e", "gif", "-e", "webp" },
                    attach_mappings = function(_, map)
                        local function embed_image(prompt_bufnr)
                            local entry = action_state.get_selected_entry()
                            local filepath = entry[1]
                            actions.close(prompt_bufnr)
                            require("img-clip").paste_image(nil, filepath)
                        end

                        map("i", "<CR>", embed_image)
                        map("n", "<CR>", embed_image)

                        return true
                    end,
                })
            end,
            desc = "Telescope find images",
        },
    },
}
