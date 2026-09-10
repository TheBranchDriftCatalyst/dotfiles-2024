vim.g.mapleader = " "

-- nix supplies lazy.nvim and every plugin (see home/neovim.nix). The plugin
-- set's store hash keys the cache dir, so a plugin bump recompiles base46.
local nix = require "nix_paths"
vim.g.base46_cache = vim.fn.stdpath "data" .. "/nvchad/base46-" .. nix.gen .. "/"

vim.opt.rtp:prepend(nix.lazy)

local lazy_config = require "configs.lazy"

-- load plugins
require("lazy").setup({
  {
    "NvChad/NvChad",
    lazy = false,
    branch = "v2.5",
    import = "nvchad.plugins",
  },

  { import = "plugins" },
}, lazy_config)

-- base46's compile normally runs as lazy's install-time build hook, which
-- never fires under nix — so compile here on each new plugin generation.
if not vim.uv.fs_stat(vim.g.base46_cache .. "defaults") then
  require("base46").load_all_highlights()
end

-- load theme
dofile(vim.g.base46_cache .. "defaults")
dofile(vim.g.base46_cache .. "statusline")

require "options"
require "nvchad.autocmds"

vim.schedule(function()
  require "mappings"
end)
