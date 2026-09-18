-- load defaults i.e lua_lsp
require("nvchad.configs.lspconfig").defaults()

-- nvim 0.11+ native LSP API. nvim-lspconfig stays installed purely as the
-- data source (its lsp/*.lua server definitions land on runtimepath);
-- require("lspconfig") itself is the deprecated framework — don't.
local servers = { "html", "cssls" }
local nvlsp = require "nvchad.configs.lspconfig"

for _, lsp in ipairs(servers) do
  vim.lsp.config(lsp, {
    on_attach = nvlsp.on_attach,
    on_init = nvlsp.on_init,
    capabilities = nvlsp.capabilities,
  })
end
vim.lsp.enable(servers)

-- single server with extra settings, example:
-- vim.lsp.config("ts_ls", {
--   on_attach = nvlsp.on_attach,
--   settings = { ... },
-- })
-- vim.lsp.enable { "ts_ls" }
