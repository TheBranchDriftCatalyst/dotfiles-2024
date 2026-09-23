-- Workspace pills: number + the app icons living in that workspace
-- (sketchybar-app-font glyphs via icon_map). aerospace fires the custom
-- event (exec-on-workspace-change in rice.nix); front_app_switched doubles
-- as a cheap refresh proxy for windows moving between workspaces.
local colors = require("colors")
local settings = require("settings")
local icon_map = require("icon_map")

sbar.add("event", "aerospace_workspace_change")

local function refresh_apps(ws, item)
  sbar.exec(settings.aerospace .. " list-windows --workspace " .. ws .. " --format '%{app-name}'", function(out)
    local icons, seen = "", {}
    for app in string.gmatch(out or "", "[^\r\n]+") do
      if app ~= "" and not seen[app] then
        seen[app] = true
        icons = icons .. (icon_map[app] or ":default:")
      end
    end
    if icons == "" then
      item:set({ label = { drawing = false } })
    else
      item:set({ label = { string = icons, drawing = true } })
    end
  end)
end

local function paint(item, focused)
  item:set({
    icon = { color = focused and colors.deep or colors.dim },
    label = { color = focused and colors.deep or colors.dim },
    background = { color = focused and colors.glow or colors.transparent },
  })
end

local spaces = {}
for ws = 1, 9 do
  local space = sbar.add("item", "space." .. ws, {
    position = "left",
    icon = { string = tostring(ws) },
    label = {
      -- app glyphs render in the app font, not the text font
      font = { family = "sketchybar-app-font", style = "Regular", size = 14.0 },
      y_offset = -1,
      drawing = false,
    },
    click_script = settings.aerospace .. " workspace " .. ws,
  })
  spaces[ws] = space

  space:subscribe("aerospace_workspace_change", function(env)
    paint(space, env.FOCUSED_WORKSPACE == tostring(ws))
    refresh_apps(ws, space)
  end)
end

-- window-focus changes are the closest signal we get for "apps moved around"
local watcher = sbar.add("item", "space.watcher", { drawing = false })
watcher:subscribe("front_app_switched", function()
  for ws, item in pairs(spaces) do
    refresh_apps(ws, item)
  end
end)

-- initial paint (launchd start / sketchybar --reload)
sbar.exec(settings.aerospace .. " list-workspaces --focused", function(out)
  local focused = (out or ""):gsub("%s+", "")
  for ws, item in pairs(spaces) do
    paint(item, tostring(ws) == focused)
    refresh_apps(ws, item)
  end
end)
