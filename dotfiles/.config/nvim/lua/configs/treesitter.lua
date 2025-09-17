local options = {
  ensure_installed = {
    "vim", "lua", "vimdoc",
    "html", "css", "javascript", "typescript",
    "go", "gomod", "gowork", "gosum",
    "python",
    "yaml", "json", "toml",
    "bash", "fish",
    "markdown", "markdown_inline",
    "regex", "comment",
  },

  highlight = {
    enable = true,
    use_languagetree = true,
  },

  indent = { enable = true },

  -- Enable incremental selection
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = "<C-space>",
      node_incremental = "<C-space>",
      scope_incremental = "<nop>",
      node_decremental = "<bs>",
    },
  },

  -- Enable text objects
  textobjects = {
    select = {
      enable = true,
      lookahead = true,
      keymaps = {
        ["af"] = "@function.outer",
        ["if"] = "@function.inner",
        ["ac"] = "@class.outer",
        ["ic"] = "@class.inner",
      },
    },
  },
}

return options