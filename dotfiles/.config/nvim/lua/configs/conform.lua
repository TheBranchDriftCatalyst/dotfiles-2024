local options = {
  formatters_by_ft = {
    lua = { "stylua" },

    -- 🐹 Go
    go = { "goimports", "gofumpt" },

    -- 🐍 Python
    python = { "isort", "black" },

    -- 📝 Web/Config
    css = { "prettier" },
    html = { "prettier" },
    javascript = { "prettier" },
    typescript = { "prettier" },
    json = { "prettier" },
    yaml = { "prettier" },
    markdown = { "prettier" },

    -- 🔧 Shell
    sh = { "shfmt" },
    bash = { "shfmt" },
  },

  format_on_save = {
    -- These options will be passed to conform.format()
    timeout_ms = 500,
    lsp_fallback = true,
  },
}

return options
