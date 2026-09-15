local colors = require("colors")
local settings = require("settings")

-- right-side items stack right-to-left in add order, so this file reads
-- from the right edge inward: clock, battery, cpu, memory, docker, k8s.
--
-- Every widget gets a hover/click popup. Popup contents are refreshed in
-- each widget's routine callback (the data is being fetched anyway), so
-- hovering shows warm data instantly instead of waiting on an exec.
--
-- Interaction model: hover = glance (popup follows the cursor, read-only),
-- click = pin (popup stays open so its rows can be clicked). docker/k8s/
-- cpu/mem popups are "decks": clicking a row unfolds verb buttons beneath it
-- (sketchybar popups are strictly one item per line — one click target each —
-- so side-by-side buttons on a row aren't possible; the unfolding submenu is
-- the native pattern). Destructive verbs confirm: the button goes hot pink
-- and names its target, a second click fires, 4s to change your mind.

-- ── popup helpers ──────────────────────────────────────────────────────────
-- extras: additional bar items (e.g. the mem bar's segments) that act as
-- hover/click surfaces for the same popup, sharing the pin state
local function hover_popup(item, extras)
  local pinned = false
  local function enter()
    item:set({ popup = { drawing = true } })
  end
  -- plain exited fires the moment the cursor leaves the bar item (including
  -- travel down into the popup) — so only the pinned state survives it
  local function exit()
    if not pinned then
      item:set({ popup = { drawing = false } })
    end
  end
  local function toggle_pin()
    pinned = not pinned
    item:set({ popup = { drawing = pinned } })
  end
  for _, it in ipairs({ item, table.unpack(extras or {}) }) do
    it:subscribe("mouse.entered", enter)
    it:subscribe("mouse.exited", exit)
    it:subscribe("mouse.clicked", toggle_pin)
  end
  item:subscribe("mouse.exited.global", function()
    pinned = false
    item:set({ popup = { drawing = false } })
  end)
end

-- fixed pool of n reusable rows under popup.<owner>; returns fill(lines)
local function popup_rows(owner, n, width)
  local rows = {}
  for i = 1, n do
    rows[i] = sbar.add("item", owner .. ".row" .. i, {
      position = "popup." .. owner,
      drawing = false,
      icon = { drawing = false },
      label = {
        font = { family = settings.font, style = "Regular", size = 12.0 },
        align = "left",
      },
      width = width,
    })
  end
  return function(lines)
    for i = 1, n do
      if lines[i] then
        rows[i]:set({ drawing = true, label = { string = lines[i] } })
      else
        rows[i]:set({ drawing = false })
      end
    end
  end
end

local function lines_of(s)
  local t = {}
  for line in (s or ""):gmatch("[^\n]+") do
    t[#t + 1] = line
  end
  return t
end

-- truncate with an ellipsis so trailing columns never fall off the edge
local function clip(s, n)
  if #s <= n then
    return s
  end
  return s:sub(1, n - 1) .. "…"
end

-- ── deck: a popup whose rows unfold into verb buttons ──────────────────────
-- Layout, top to bottom: header band (acid on mid), a 2px sunBot horizon
-- rule, then n rows. Clicking a row unfolds its verbs beneath it, each verb
-- a full-width button line (glyph + word). A verb with confirm set asks
-- once: the button goes hot pink and shows the confirm text, a second click
-- fires, 4s reverts.
--
-- spec.verbs(payload) -> up to spec.max verb tables:
--   { icon, name, color, cmd, confirm = "kill web-1?" }
-- Returned deck: fill(title, entries) renders; entries[i] =
-- { glyph, color, text, tcolor, payload } — no payload means info-only row.
-- Assign deck.refresh after wiring so actions re-fetch when they land.
local function deck(owner, n, width, spec)
  local d = { refresh = nil }
  local rows, entries, verb_items, verbs = {}, {}, {}, {}
  local open, confirming, gen = nil, nil, 0

  local head = sbar.add("item", owner .. ".head", {
    position = "popup." .. owner,
    icon = { drawing = false },
    label = {
      font = { family = settings.font, style = "Bold", size = 13.0 },
      color = colors.sunTop,
      align = "left",
      padding_left = 10,
    },
    width = width,
    background = { drawing = true, color = colors.mid, height = 26, corner_radius = 5 },
  })
  sbar.add("item", owner .. ".horizon", {
    position = "popup." .. owner,
    icon = { drawing = false },
    label = { drawing = false },
    width = width,
    background = { drawing = true, color = colors.sunBot, height = 2, corner_radius = 1 },
  })

  local function restyle_verb(i, j)
    local v = verbs[i] and verbs[i][j]
    if not v then
      return
    end
    verb_items[i][j]:set({
      icon = { string = v.icon, color = v.color },
      label = { string = v.name, color = colors.accent },
      background = { color = colors.mid },
    })
  end

  local function collapse()
    if not open then
      return
    end
    for j = 1, spec.max do
      verb_items[open][j]:set({ drawing = false })
    end
    rows[open]:set({ background = { color = colors.transparent } })
    verbs[open], open, confirming = nil, nil, nil
  end

  local function expand(i)
    collapse()
    open = i
    verbs[i] = spec.verbs(entries[i].payload)
    rows[i]:set({ background = { color = colors.hover } })
    for j = 1, spec.max do
      if verbs[i][j] then
        restyle_verb(i, j)
        verb_items[i][j]:set({ drawing = true })
      end
    end
  end

  local function fire(cmd)
    collapse()
    sbar.exec(cmd, function()
      if d.refresh then
        d.refresh()
      end
    end)
  end

  for i = 1, n do
    local row = sbar.add("item", owner .. ".row" .. i, {
      position = "popup." .. owner,
      drawing = false,
      icon = {
        font = { family = settings.font, style = "Regular", size = 11.0 },
        width = 26,
        align = "center",
      },
      label = {
        font = { family = settings.font, style = "Regular", size = 12.0 },
        align = "left",
      },
      width = width,
      background = { drawing = true, color = colors.transparent, height = 22, corner_radius = 4 },
    })
    rows[i] = row

    row:subscribe("mouse.entered", function()
      if entries[i] and entries[i].payload and open ~= i then
        row:set({ background = { color = colors.hover } })
      end
    end)
    row:subscribe("mouse.exited", function()
      if open ~= i then
        row:set({ background = { color = colors.transparent } })
      end
    end)
    row:subscribe("mouse.clicked", function()
      local e = entries[i]
      if not e or not e.payload then
        return
      end
      if open == i then
        collapse()
      else
        expand(i)
      end
    end)

    verb_items[i] = {}
    for j = 1, spec.max do
      local v = sbar.add("item", owner .. ".row" .. i .. ".verb" .. j, {
        position = "popup." .. owner,
        drawing = false,
        icon = {
          font = { family = settings.font, style = "Regular", size = 11.0 },
          width = 30,
          align = "center",
          padding_left = 22,
        },
        label = {
          font = { family = settings.font, style = "Regular", size = 12.0 },
          align = "left",
          padding_right = 10,
        },
        width = width,
        background = { drawing = true, color = colors.mid, height = 22, corner_radius = 4 },
      })
      verb_items[i][j] = v

      v:subscribe("mouse.entered", function()
        if verbs[i] and verbs[i][j] and confirming ~= i * 100 + j then
          v:set({ background = { color = colors.hover } })
        end
      end)
      v:subscribe("mouse.exited", function()
        if confirming ~= i * 100 + j then
          restyle_verb(i, j)
        end
      end)
      v:subscribe("mouse.clicked", function()
        local verb = verbs[i] and verbs[i][j]
        if not verb then
          return
        end
        if verb.confirm and confirming ~= i * 100 + j then
          gen = gen + 1
          local my_gen = gen
          confirming = i * 100 + j
          v:set({
            icon = { string = "󰐥", color = colors.deep },
            label = { string = verb.confirm, color = colors.deep },
            background = { color = colors.hot },
          })
          sbar.delay(4, function()
            if confirming == i * 100 + j and gen == my_gen then
              confirming = nil
              restyle_verb(i, j)
            end
          end)
          return
        end
        fire(verb.cmd)
      end)
    end
  end

  d.fill = function(title, list)
    collapse()
    head:set({ label = { string = title } })
    for i = 1, n do
      entries[i] = list[i]
      if list[i] then
        local e = list[i]
        rows[i]:set({
          drawing = true,
          icon = { string = e.glyph or "", color = e.color or colors.glow },
          label = { string = e.text, color = e.tcolor or colors.accent },
          background = { color = colors.transparent },
        })
      else
        rows[i]:set({ drawing = false })
      end
    end
  end

  return d
end

-- ── clock ─────────────────────────────────────────────────────────────────
local clock = sbar.add("item", "clock", {
  position = "right",
  update_freq = 10,
  icon = { string = "󰥔" },
})
local clock_fill = popup_rows("clock", 9, 185)
clock:subscribe({ "routine", "forced", "system_woke" }, function()
  sbar.exec([[date '+%a %m/%d %H:%M'; date '+%A, %B %e %Y'; cal]], function(out)
    local lns = lines_of(out)
    clock:set({ label = { string = lns[1] or "" } })
    clock_fill({ table.unpack(lns, 2) })
  end)
end)
hover_popup(clock)

-- ── battery ───────────────────────────────────────────────────────────────
local battery = sbar.add("item", "battery", {
  position = "right",
  update_freq = 120,
})
local battery_fill = popup_rows("battery", 3, 185)
battery:subscribe({ "routine", "forced", "power_source_change", "system_woke" }, function()
  sbar.exec(
    [[pmset -g batt; /usr/sbin/ioreg -rn AppleSmartBattery | grep -E '"(CycleCount|DesignCapacity|AppleRawMaxCapacity)" =']],
    function(out)
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

      local status = out:match("%d+%%; (%a+)") or (charging and "charging" or "on battery")
      local time = out:match("(%d+:%d+) remaining")
      if time == "0:00" then
        time = nil
      end -- pmset reports 0:00 when charged
      local cycles = out:match('"CycleCount" = (%d+)')
      local design = tonumber(out:match('"DesignCapacity" = (%d+)'))
      local rawmax = tonumber(out:match('"AppleRawMaxCapacity" = (%d+)'))
      local health = (design and rawmax) and string.format(" · health %.0f%%", rawmax / design * 100) or ""
      battery_fill({
        pct .. "% · " .. status,
        time and (time .. " remaining") or "no time estimate",
        cycles and ("cycles " .. cycles .. health) or nil,
      })
    end
  )
end)
hover_popup(battery)

-- ── cpu: top-process deck ─────────────────────────────────────────────────
-- verbs shared by every process row (cpu hogs, mem hogs): quit asks nicely,
-- force kill confirms in hot pink first
local function proc_verbs(p)
  return {
    { icon = "󰅖", name = "quit", color = colors.sunTop, cmd = "kill " .. p.pid },
    {
      icon = "󰚌",
      name = "force kill",
      color = colors.hot,
      cmd = "kill -9 " .. p.pid,
      confirm = "force kill " .. clip(p.name, 18) .. "?",
    },
  }
end

local cpu = sbar.add("item", "cpu", {
  position = "right",
  update_freq = 5,
  icon = { string = "󰻠" },
})
local cpu_deck = deck("cpu", 5, 280, { max = 2, verbs = proc_verbs })
local function cpu_refresh()
  sbar.exec(
    [[sysctl -n vm.loadavg; ps -Aceo pcpu,pid,comm -r | awk -v n=$(sysctl -n hw.ncpu) 'NR>1 {s+=$1} NR>1 && NR<=6 {printf "PROC %s %s %s\n", $1, $2, substr($0, index($0, $3))} END {printf "TOTAL %.0f\n", s/n}']],
    function(out)
      local list, load = {}, ""
      for _, l in ipairs(lines_of(out)) do
        local total = l:match("^TOTAL (%d+)")
        local pcpu, pid, name = l:match("^PROC ([%d.]+) (%d+) (.+)$")
        if total then
          cpu:set({ label = { string = total .. "%" } })
        elseif l:sub(1, 1) == "{" then
          load = l:gsub("[{}]", ""):gsub("^%s+", ""):gsub("%s+$", "")
        elseif pcpu then
          local n = tonumber(pcpu)
          list[#list + 1] = {
            glyph = "●",
            color = n > 50 and colors.red or n > 20 and colors.sunTop or colors.glow,
            text = string.format("%5.1f%%  %s", n, clip(name, 24)),
            payload = { pid = pid, name = name },
          }
        end
      end
      cpu_deck.fill("load " .. load, list)
    end
  )
end
cpu_deck.refresh = cpu_refresh
cpu:subscribe({ "routine", "forced" }, cpu_refresh)
hover_popup(cpu)

-- ── memory: stacked composition bar, deets in the popup ───────────────────
-- Activity Monitor's taxonomy, derived from vm_stat pages:
--   app        = anonymous - purgeable        (writable, in active use)
--   wired      = wired down                   (locked, can never page out)
--   compressed = occupied by compressor
--   cached     = file-backed + purgeable      (freeable on demand)
--   free       = everything else (incl. actual free + kernel slack)
-- Ordered here as drawn left→right; items are added in reverse because of
-- the right-side stacking rule above.
local MEMBAR_WIDTH = 60
local segments = {
  { key = "app", name = "App Memory", color = colors.glow },
  { key = "wired", name = "Wired", color = colors.sunTop },
  { key = "compressed", name = "Compressed", color = colors.red },
  { key = "cached", name = "Cached Files", color = colors.accent },
  { key = "free", name = "Free", color = colors.mid },
}

for i = #segments, 1, -1 do
  segments[i].item = sbar.add("item", "mem.seg." .. segments[i].key, {
    position = "right",
    width = MEMBAR_WIDTH / #segments,
    padding_left = 0,
    padding_right = 0,
    icon = { drawing = false },
    label = { drawing = false },
    background = {
      drawing = true,
      color = segments[i].color,
      height = 10,
      corner_radius = 0,
    },
  })
end

local mem = sbar.add("item", "mem", {
  position = "right",
  update_freq = 10,
  icon = { string = "󰍛" },
  label = { drawing = false },
  padding_right = 2,
})

-- deck rows: segment legend (info), swap (info), top memory hogs (kill
-- verbs), then the utility rows — evict file caches (purge) and Activity
-- Monitor. purge(8) is root-only; rice.nix grants exactly that binary
-- NOPASSWD so the button can fire it non-interactively.
local mem_deck = deck("mem", 12, 300, {
  max = 2,
  verbs = function(p)
    if p.kind == "purge" then
      return { { icon = "󰃢", name = "purge now", color = colors.accent, cmd = "sudo -n /usr/sbin/purge" } }
    elseif p.kind == "am" then
      return { { icon = "󰄨", name = "open", color = colors.accent, cmd = "open -a 'Activity Monitor'" } }
    end
    return proc_verbs(p)
  end,
})

-- one bordered pill around icon + segments so it reads as a single widget
local mem_members = { "mem" }
for _, s in ipairs(segments) do
  mem_members[#mem_members + 1] = "mem.seg." .. s.key
end
sbar.add("bracket", "mem.bar", mem_members, {
  background = {
    drawing = true,
    color = colors.transparent,
    border_color = colors.dim,
    border_width = 1,
    height = 18,
    corner_radius = 5,
  },
})

local function mem_refresh()
  sbar.exec(
    [[/usr/bin/vm_stat; /usr/sbin/sysctl -n vm.swapusage
      echo MEMTOTAL $(/usr/sbin/sysctl -n hw.memsize) $(/usr/sbin/sysctl -n kern.memorystatus_vm_pressure_level)
      ps -Aceo rss=,pid=,comm= -m | head -4 | awk '{print "PROC " $0}']],
    function(out)
      out = out or ""
      local page = tonumber(out:match("page size of (%d+)")) or 16384
      local function pages(pat)
        return tonumber(out:match(pat .. ":%s+(%d+)")) or 0
      end
      local total, level = out:match("MEMTOTAL (%d+) (%d+)")
      total = tonumber(total) or 0
      level = tonumber(level) or 1 -- 1 normal / 2 warn / 4 critical
      if total <= 0 then
        return
      end

      local purgeable = pages("Pages purgeable")
      local vals = {
        app = (pages("Anonymous pages") - purgeable) * page,
        wired = pages("Pages wired down") * page,
        compressed = pages("Pages occupied by compressor") * page,
        cached = (pages("File%-backed pages") + purgeable) * page,
      }
      vals.free = math.max(total - vals.app - vals.wired - vals.compressed - vals.cached, 0)

      local used = vals.app + vals.wired + vals.compressed
      local level_name = level >= 4 and "critical" or level >= 2 and "warning" or "normal"
      local pressure_color = level >= 4 and colors.red or level >= 2 and colors.sunTop or colors.glow
      mem:set({ icon = { color = pressure_color } })

      local swap_total = tonumber(out:match("total = ([%d%.]+)M")) or 0
      local swap_used = tonumber(out:match("used = ([%d%.]+)M")) or 0

      local list = {}
      for _, s in ipairs(segments) do
        s.item:set({ width = math.max(math.floor(vals[s.key] / total * MEMBAR_WIDTH + 0.5), 1) })
        list[#list + 1] = {
          glyph = "󰝤",
          color = s.color,
          text = string.format("%-13s %6.1f GB", s.name, vals[s.key] / 2 ^ 30),
        }
      end
      if swap_total > 0 then
        list[#list + 1] = {
          glyph = "󰝤",
          color = colors.dim,
          text = string.format("%-13s %6.1f GB", "Swap", swap_used / 1024),
        }
      end
      for _, l in ipairs(lines_of(out)) do
        local rss, pid, name = l:match("^PROC%s+(%d+)%s+(%d+)%s+(.+)$")
        if rss then
          list[#list + 1] = {
            glyph = "●",
            color = colors.accent,
            text = string.format("%-22s %5.1f GB", clip(name, 22), rss * 1024 / 2 ^ 30),
            payload = { pid = pid, name = name },
          }
        end
      end
      list[#list + 1] =
        { glyph = "󰃢", color = colors.accent, text = "evict file caches", payload = { kind = "purge" } }
      list[#list + 1] = { glyph = "󰄨", color = colors.accent, text = "Activity Monitor", payload = { kind = "am" } }

      mem_deck.fill(string.format("used %.1f/%.0f GB, pressure %s", used / 2 ^ 30, total / 2 ^ 30, level_name), list)
    end
  )
end
mem_deck.refresh = mem_refresh
mem:subscribe({ "routine", "forced", "system_woke" }, mem_refresh)
-- the composition bar's segments share the popup (hover glances, click pins)
local seg_items = {}
for _, s in ipairs(segments) do
  seg_items[#seg_items + 1] = s.item
end
hover_popup(mem, seg_items)

-- ── docker: container deck (colima) ────────────────────────────────────────
-- click a row to pause/unpause, right-click twice to kill
local CTR_PATH = "PATH=/etc/profiles/per-user/dj/bin:/run/current-system/sw/bin:$PATH"
local docker = sbar.add("item", "docker", {
  position = "right",
  update_freq = 30,
  icon = { string = "󰡨" },
})
local docker_deck = deck("docker", 8, 300, {
  max = 3,
  verbs = function(p)
    local dc = CTR_PATH .. "; docker "
    return {
      p.state == "paused" and { icon = "󰐊", name = "resume", color = colors.glow, cmd = dc .. "unpause " .. p.name }
        or { icon = "󰏤", name = "pause", color = colors.sunTop, cmd = dc .. "pause " .. p.name },
      { icon = "󰜉", name = "restart", color = colors.accent, cmd = dc .. "restart " .. p.name },
      {
        icon = "󰅖",
        name = "kill",
        color = colors.hot,
        cmd = dc .. "kill " .. p.name,
        confirm = "kill " .. p.name .. "?",
      },
    }
  end,
})
local function docker_refresh()
  sbar.exec(
    CTR_PATH
      .. [[; if docker info >/dev/null 2>&1; then docker ps --format '{{.Names}}|{{.State}}|{{.Status}}' | head -8; else echo DOWN; fi]],
    function(out)
      out = (out or ""):gsub("%s+$", "")
      if out == "DOWN" then
        docker:set({ icon = { color = colors.dim }, label = { string = "–", color = colors.dim } })
        docker_deck.fill("docker is down", { { text = "colima start brings it back", tcolor = colors.dim } })
        return
      end
      local list = {}
      for _, l in ipairs(lines_of(out)) do
        local name, state, status = l:match("^(.-)|(.-)|(.*)$")
        if name then
          local paused = state == "paused"
          list[#list + 1] = {
            glyph = paused and "◌" or "●",
            color = paused and colors.sunTop or colors.glow,
            text = string.format("%-20s %s", clip(name, 20), clip(status, 14)),
            payload = { name = name, state = state },
          }
        end
      end
      local n = #list
      docker:set({
        icon = { color = n > 0 and colors.accent or colors.dim },
        label = { string = tostring(n), color = n > 0 and colors.accent or colors.dim },
      })
      if n == 0 then
        docker_deck.fill("colima, idle", { { text = "no containers running", tcolor = colors.dim } })
      else
        docker_deck.fill(n .. (n == 1 and " container" or " containers") .. " on colima", list)
      end
    end
  )
end
docker_deck.refresh = docker_refresh
docker:subscribe({ "routine", "forced", "system_woke" }, docker_refresh)
hover_popup(docker)

-- ── k8s: deployment deck ───────────────────────────────────────────────────
-- click a row to scale a deployment to zero (previous replica count is
-- stashed in a teak-prev-replicas annotation, so a second click scales it
-- right back); right-click twice bounces it via rollout restart.
local k8s = sbar.add("item", "k8s", {
  position = "right",
  update_freq = 120,
  icon = { string = "󱃾" },
  label = { max_chars = 24 },
})
local k8s_deck = deck("k8s", 10, 340, {
  max = 2,
  verbs = function(p)
    local kc = "kubectl -n " .. p.ns .. " "
    local scale
    if p.want > 0 then
      scale = {
        icon = "󰏤",
        name = "scale to 0",
        color = colors.sunTop,
        cmd = CTR_PATH
          .. "; "
          .. kc
          .. "annotate deploy "
          .. p.name
          .. " teak-prev-replicas="
          .. p.want
          .. " --overwrite && "
          .. kc
          .. "scale deploy "
          .. p.name
          .. " --replicas=0",
      }
    else
      scale = {
        icon = "󰐊",
        name = "scale to " .. (p.prev or 1),
        color = colors.glow,
        cmd = CTR_PATH
          .. "; "
          .. kc
          .. "scale deploy "
          .. p.name
          .. " --replicas="
          .. (p.prev or 1)
          .. " && "
          .. kc
          .. "annotate deploy "
          .. p.name
          .. " teak-prev-replicas-",
      }
    end
    return {
      scale,
      {
        icon = "󰜉",
        name = "bounce",
        color = colors.accent,
        cmd = CTR_PATH .. "; " .. kc .. "rollout restart deploy " .. p.name,
        confirm = "bounce " .. p.name .. "?",
      },
    }
  end,
})
local function k8s_refresh()
  sbar.exec(
    CTR_PATH
      .. [[; ctx=$(kubectl config current-context 2>/dev/null) || { echo NOCTX; exit 0; }
      echo "CTX $ctx"
      kubectl get nodes --no-headers --request-timeout=3s 2>/dev/null | awk '{print "NODE " $1 " " $2}'
      kubectl get deploy -A --no-headers --request-timeout=3s -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,READY:.status.readyReplicas,WANT:.spec.replicas,PREV:.metadata.annotations.teak-prev-replicas' 2>/dev/null | head -10 | awk '{print "DEP " $0}']],
    function(out)
      out = (out or ""):gsub("%s+$", "")
      if out == "NOCTX" or out == "" then
        k8s:set({ icon = { color = colors.dim }, label = { string = "–", color = colors.dim } })
        k8s_deck.fill("kubernetes", { { text = "no kubectl context configured", tcolor = colors.dim } })
        return
      end
      local ctx, ready, total = "?", 0, 0
      local list = {}
      for _, l in ipairs(lines_of(out)) do
        local c = l:match("^CTX (.+)")
        local nname, nstatus = l:match("^NODE (%S+) (%S+)")
        local ns, name, dready, dwant, dprev = l:match("^DEP (%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")
        if c then
          ctx = c
        elseif nname then
          total = total + 1
          if nstatus == "Ready" then
            ready = ready + 1
          end
        elseif ns then
          -- kubectl prints <none> for absent values; tonumber() maps it to 0/nil
          local want = tonumber(dwant) or 0
          local rdy = tonumber(dready) or 0
          local paused = want == 0
          list[#list + 1] = {
            glyph = paused and "◌" or "●",
            color = paused and colors.sunTop or (rdy < want and colors.red or colors.glow),
            text = string.format("%-32s %d/%d", clip(ns .. "/" .. name, 32), rdy, want),
            payload = { ns = ns, name = name, want = want, prev = tonumber(dprev) },
          }
        end
      end
      if total == 0 then -- context set but cluster unreachable
        k8s:set({ icon = { color = colors.red }, label = { string = ctx .. " ✗", color = colors.dim } })
        k8s_deck.fill(ctx, { { text = "cluster unreachable", tcolor = colors.dim } })
        return
      end
      k8s:set({
        icon = { color = colors.accent },
        label = { string = string.format("%s %d/%d", ctx, ready, total), color = colors.accent },
      })
      local title = string.format("%s   %d/%d nodes", ctx, ready, total)
      if #list == 0 then
        k8s_deck.fill(title, { { text = "no deployments", tcolor = colors.dim } })
      else
        k8s_deck.fill(title, list)
      end
    end
  )
end
k8s_deck.refresh = k8s_refresh
k8s:subscribe({ "routine", "forced", "system_woke" }, k8s_refresh)
hover_popup(k8s)
