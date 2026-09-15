local colors = require("colors")
local icon_map = require("icon_map")

local front = sbar.add("item", "front_app", {
  position = "left",
  icon = {
    font = { family = "sketchybar-app-font", style = "Regular", size = 14.0 },
    color = colors.glow,
  },
  label = { color = colors.glow, font = { style = "Bold" } },
})

front:subscribe("front_app_switched", function(env)
  front:set({
    icon = { string = icon_map[env.INFO] or ":default:" },
    label = { string = env.INFO },
  })
end)
