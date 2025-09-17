-- This file needs to have same structure as nvconfig.lua 
-- https://github.com/NvChad/ui/blob/v2.5/lua/nvconfig.lua
-- Please read that file to know all available options :( 

---@type ChadrcConfig
local M = {}

M.base46 = {
	theme = "2077", -- Cyberpunk 2077 theme

	hl_override = {
		Comment = { italic = true },
		["@comment"] = { italic = true },
	},
}

return M
