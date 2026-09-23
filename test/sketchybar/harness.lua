-- ─────────────────────────────────────────────────────────────────────────────
-- test/sketchybar/harness.lua — drive the REAL widgets.lua against a stubbed
-- `sbar`, with no sketchybar process and no macOS involved.
--
-- WHY THIS EXISTS: on 2026-09-22 the bar froze several times a day. The cause
-- was a mach IPC DEADLOCK, proven by sampling both stacks mid-freeze — each
-- process parked in mach_msg2_trap at 0% CPU, sending to the other while
-- neither drained its own port. The mechanism, from the C on both sides:
--   * sketchybar delivers every mouse.* event from inside its Carbon dispatch
--     via bar_item_update -> mach_send_message(..., await_response=false), and
--     that send is MACH_SEND_MSG with NO timeout: it blocks on a full queue.
--     (bar_item.c:169; bar_item_mouse_entered/_exited/on_click all route here)
--   * SbarLua sends every sbar command back with response=true and a blocking,
--     untimed send of its own. (sketchybar.c:82, mach.h)
-- So a callback that issues an sbar command while sketchybar is still inside
-- the dispatch can wedge both processes permanently.
--
-- THE INVARIANT THIS FILE PROTECTS: no mouse.* handler may issue an sbar
-- command synchronously. Each must go through deferred(), which only arms a
-- CFRunLoopTimer and runs the body on a later runloop pass.
--
-- Section 2 must be driven with state that would ACTUALLY make the handler do
-- something (a popup open, entries populated). Firing a guarded handler in a
-- state where it early-returns proves nothing — and that short-circuit is also
-- why the freeze looked random rather than reproducible.
--
-- Section 4 covers the companion fix: rendering a popup nobody is looking at
-- costs n+1 blocking round-trips per routine tick (mem alone was 13 every 10s,
-- ~95% of all popup IPC) for pixels nobody sees.
-- ─────────────────────────────────────────────────────────────────────────────

local subs = {} -- event -> { {name, fn}, ... }
local calls = {} -- every item:set() this pass, in order
local delayed = {} -- callbacks parked by sbar.delay: the runloop queue

local Item = {}
Item.__index = Item
function Item:set(t)
  calls[#calls + 1] = { name = self.name, t = t }
  return self
end
function Item:subscribe(ev, fn)
  for _, e in ipairs(type(ev) == "table" and ev or { ev }) do
    subs[e] = subs[e] or {}
    subs[e][#subs[e] + 1] = { name = self.name, fn = fn }
  end
  return self
end

-- widgets.lua expects the same GLOBAL that init.lua sets up
sbar = {
  add = function(_, name, _)
    return setmetatable({ name = name }, Item)
  end,
  -- Real SbarLua runs the callback from the runloop with (output, exit_code).
  -- cpu and clock get realistic canned output so their decks end up holding
  -- actual rows with payloads — without that, every handler below early-returns
  -- and the assertions pass vacuously. The rest return "" (their parsers are
  -- not what this suite is about). pcall mirrors SbarLua's own lua_pcall.
  exec = function(cmd, cb)
    if not cb then
      return
    end
    local out = ""
    if type(cmd) == "string" then
      if cmd:find("vm.loadavg", 1, true) then
        out = "{ 1.50 1.20 1.10 }\nPROC 42.5 501 WindowServer\nPROC 12.0 777 zsh\nTOTAL 27\n"
      elseif cmd:find("date '+%a", 1, true) then
        out = "Tue 09/22 15:30\nTuesday, September 22 2026\n   September 2026\nSu Mo Tu We Th Fr Sa\n"
      end
    end
    pcall(cb, out, 0)
  end,
  delay = function(_, fn)
    delayed[#delayed + 1] = fn
  end,
}

require("widgets")

-- ── drivers ──────────────────────────────────────────────────────────────────
local function runloop() -- the later pass deferred() defers to
  local q = delayed
  delayed = {}
  for _, fn in ipairs(q) do
    fn()
  end
end
local function fire(event, name) -- the callback ONLY, no runloop pass
  for _, s in ipairs(subs[event] or {}) do
    if name == nil or s.name == name then
      s.fn()
    end
  end
end
local function act(event, name) -- callback + runloop: a complete interaction
  fire(event, name)
  runloop()
end
local function reset()
  calls = {}
end
local function popup_changes() -- only popup show/hide, for the state machine
  local out = {}
  for _, c in ipairs(calls) do
    if c.t.popup and c.t.popup.drawing ~= nil then
      out[#out + 1] = { name = c.name, drawing = c.t.popup.drawing }
    end
  end
  return out
end
local function sets_under(prefix) -- IPC aimed at one widget's popup children
  local n = 0
  for _, c in ipairs(calls) do
    if c.name:sub(1, #prefix) == prefix then
      n = n + 1
    end
  end
  return n
end

-- ── assertions (same vocabulary as test/run.sh) ──────────────────────────────
local fails = 0
local function check(desc, cond)
  print(cond and ("  \27[0;32m✔\27[0m " .. desc) or ("  \27[0;31m✖\27[0m " .. desc))
  if not cond then
    fails = fails + 1
  end
end

print("══ 1. subscription accounting ══")
local n_exit = #(subs["mouse.exited.global"] or {})
check("exactly ONE mouse.exited.global subscriber (got " .. n_exit .. ")", n_exit == 1)
check(
  "mouse.clicked still wired per widget (got " .. #(subs["mouse.clicked"] or {}) .. ")",
  #(subs["mouse.clicked"] or {}) >= 6
)

print("══ 2. THE DEADLOCK GUARD: no mouse handler may do synchronous IPC ══")
-- open a deck and populate its rows, so every handler below has real work
act("mouse.clicked", "cpu")
act("routine", "cpu")
check("(setup) cpu deck is open with rows rendered", sets_under("cpu.") > 0)

for _, ev in ipairs({ "mouse.entered", "mouse.exited", "mouse.clicked", "mouse.exited.global" }) do
  reset()
  fire(ev) -- callback only
  local during = #calls
  reset()
  runloop() -- the deferred pass
  local after = #calls
  check(ev .. ": zero sbar commands during the callback (" .. during .. ")", during == 0)
  check(ev .. ": work actually happened on the deferred pass (" .. after .. ")", after > 0)
  -- put the deck back for the next iteration
  act("mouse.clicked", "cpu")
  act("routine", "cpu")
end

print("══ 2b. a handler with nothing to do must not even arm a timer ══")
-- Upstream SbarLua luaL_ref's every delay callback and never unrefs it, so an
-- armed timer is a permanently pinned closure. Guards keep that tied to real
-- work instead of every pixel of mouse travel.
act("mouse.exited.global")
delayed = {}
fire("mouse.entered", "k8s.row1") -- k8s deck has never rendered: no entries
check("hover with nothing to do arms no timer (" .. #delayed .. ")", #delayed == 0)
act("mouse.clicked", "cpu")
act("routine", "cpu") -- cpu now holds real rows
delayed = {}
fire("mouse.entered", "cpu.row1")
check("hover that does real work still arms exactly one (" .. #delayed .. ")", #delayed == 1)
act("mouse.exited.global")

print("══ 3. popup state machine (behaviour must be unchanged) ══")
act("mouse.exited.global") -- start clean
reset()
act("mouse.clicked", "cpu")
local p = popup_changes()
check("click opens that widget's popup", p[#p] and p[#p].name == "cpu" and p[#p].drawing == true)
reset()
act("mouse.clicked", "mem")
p = popup_changes()
check("clicking another closes the first", p[1] and p[1].name == "cpu" and p[1].drawing == false)
check("...then opens the new one", p[#p] and p[#p].name == "mem" and p[#p].drawing == true)
reset()
act("mouse.clicked", "mem")
p = popup_changes()
check("clicking the open one closes it, no reopen", #p == 1 and p[1].name == "mem" and p[1].drawing == false)
reset()
act("mouse.exited.global")
check("walking off with nothing open is a no-op", #popup_changes() == 0)
act("mouse.clicked", "docker")
reset()
act("mouse.exited.global")
p = popup_changes()
check("walking off closes whichever popup is open", #p == 1 and p[1].name == "docker" and p[1].drawing == false)
reset()
act("mouse.exited.global")
check("a second walk-off is a no-op", #popup_changes() == 0)

print("══ 4. closed popups cost no IPC ══")
act("mouse.exited.global") -- everything closed
-- Smoke check across every widget. Weak on its own (a widget whose parser
-- yielded nothing would also score 0), so the real proof is the closed/open
-- PAIR below, run on the two widgets this suite feeds real data to.
for _, w in ipairs({ "cpu", "mem", "docker", "k8s", "clock", "battery" }) do
  reset()
  act("routine", w)
  check(
    w .. ": routine tick with popup CLOSED touches no popup rows (" .. sets_under(w .. ".") .. ")",
    sets_under(w .. ".") == 0
  )
end
for _, w in ipairs({ "cpu", "clock" }) do
  act("mouse.exited.global")
  reset()
  act("routine", w)
  local closed = sets_under(w .. ".")
  reset()
  act("mouse.clicked", w)
  local on_open = sets_under(w .. ".")
  reset()
  act("routine", w)
  local while_open = sets_under(w .. ".")
  check(
    w .. ": CLOSED tick renders nothing (" .. closed .. ") but opening does (" .. on_open .. ")",
    closed == 0 and on_open > 0
  )
  check(w .. ": a tick while OPEN still renders immediately (" .. while_open .. ")", while_open > 0)
end
act("mouse.exited.global")

print("")
if fails == 0 then
  print("\27[0;32m══ ALL SKETCHYBAR LOGIC TESTS PASSED ══\27[0m")
else
  print("\27[0;31m══ " .. fails .. " TEST(S) FAILED ══\27[0m")
end
os.exit(fails)
