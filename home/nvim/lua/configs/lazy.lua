local nix = require "nix_paths"

return {
  -- every spec resolves to <nix.plugins>/<name>; nothing is cloned, updated,
  -- or locked at runtime — the nixpkgs pin is the lockfile
  dev = { path = nix.plugins, patterns = { "" }, fallback = false },
  install = { missing = false },
  rocks = { enabled = false },
  pkg = { enabled = false },
  change_detection = { enabled = false },

  defaults = { lazy = true },

  ui = {
    icons = {
      ft = "",
      lazy = "󰂠 ",
      loaded = "",
      not_loaded = "",
    },
  },

  performance = {
    rtp = {
      disabled_plugins = {
        "2html_plugin",
        "tohtml",
        "getscript",
        "getscriptPlugin",
        "gzip",
        "logipat",
        "netrw",
        "netrwPlugin",
        "netrwSettings",
        "netrwFileHandlers",
        "matchit",
        "tar",
        "tarPlugin",
        "rrhelper",
        "spellfile_plugin",
        "vimball",
        "vimballPlugin",
        "zip",
        "zipPlugin",
        "tutor",
        "rplugin",
        "syntax",
        "synmenu",
        "optwin",
        "compiler",
        "bugreport",
        "ftplugin",
      },
    },
  },
}
