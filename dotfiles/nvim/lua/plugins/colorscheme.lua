return {
  -- tokyonight
  {
    "folke/tokyonight.nvim",
    lazy = true,
    opts = { style = "moon" },
  },

  -- modus-themes
  {
    "miikanissi/modus-themes.nvim",
    priority = 1000,
    opts = {
      on_highlights = function(highlights, _)
        highlights.Visual = { bg = "#bdbdbd" }
      end,
    },
  },
}
