local colors = require("colors")
local settings = require("settings")

sbar.default({
  icon = {
    font = { family = settings.font, style = "Bold", size = 14.0 },
    color = colors.glow,
    padding_left = 6,
    padding_right = 3,
  },
  label = {
    font = { family = settings.font, style = "Semibold", size = 13.0 },
    color = colors.accent,
    padding_left = 3,
    padding_right = 6,
  },
  background = { height = 24, corner_radius = 6 },
  popup = { background = { color = colors.mid, corner_radius = 6 } },
})
