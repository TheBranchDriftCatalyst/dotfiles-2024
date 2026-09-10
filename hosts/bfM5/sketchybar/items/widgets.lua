local colors = require("colors")

-- ── clock ─────────────────────────────────────────────────────────────────
local clock = sbar.add("item", "clock", {
  position = "right",
  update_freq = 10,
  icon = { string = "󰥔" },
})
clock:subscribe({ "routine", "forced", "system_woke" }, function()
  sbar.exec("date '+%a %H:%M'", function(t)
    clock:set({ label = { string = (t or ""):gsub("%s+$", "") } })
  end)
end)

-- ── battery ───────────────────────────────────────────────────────────────
local battery = sbar.add("item", "battery", {
  position = "right",
  update_freq = 120,
})
battery:subscribe({ "routine", "power_source_change", "system_woke" }, function()
  sbar.exec("pmset -g batt", function(out)
    out = out or ""
    local pct = tonumber(out:match("(%d+)%%")) or 0
    local charging = out:find("AC Power") ~= nil
    local icon = charging and "󰂄"
      or (pct > 80 and "󰁹" or pct > 60 and "󰂀" or pct > 40 and "󰁾" or pct > 20 and "󰁼" or "󰁺")
    local color = charging and colors.sunTop or (pct <= 20 and colors.red or colors.glow)
    battery:set({
      icon = { string = icon, color = color },
      label = { string = pct .. "%" },
    })
  end)
end)

-- ── cpu ───────────────────────────────────────────────────────────────────
local cpu = sbar.add("item", "cpu", {
  position = "right",
  update_freq = 5,
  icon = { string = "󰍛" },
})
cpu:subscribe({ "routine", "forced" }, function()
  sbar.exec("ps -A -o %cpu | awk -v n=$(sysctl -n hw.ncpu) '{s+=$1} END {printf \"%.0f%%\", s/n}'", function(out)
    cpu:set({ label = { string = out or "?" } })
  end)
end)
