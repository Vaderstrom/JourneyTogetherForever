-- Firsts (SPEC §8, decided with the owner 31 Oct 2026): the first Adventurer of the fellowship to do something while
-- in it: reach level 10, 20 ... 60, fall, wear a rare or an epic item, ride a mount, hold 100 gold, bring a
-- profession to 150, 225 or 300, win a PvP kill. And light-hearted tallies: who has fallen most, run most dungeons,
-- turned in most quests.
-- Each addon notices only its own deeds (ns.char.deeds: the first time of each, in the game's server time) and shares
-- them with its state (Fellowship/Hero.lua, passed on like the rest), so every addon works out the same firsts and
-- nothing extra is sent. Only a deed done after joining counts (a newcomer at 25 takes no "first to 20"). Deeds from
-- before this version are unknown: an old fellowship's early firsts stay empty.
local _, ns = ...
local L = ns.L
local F = ns.Fellowship
local FS = { RECENT = 3600, JOIN_SLACK = 600 }
ns.Firsts = FS

FS.KEYS = { "lvl10", "lvl20", "lvl30", "lvl40", "lvl50", "lvl60", "fall", "rare", "epic", "mount", "gold100",
  "prof150", "prof225", "prof300", "pvp" }
FS.TALLIES = { "falls", "runs", "quests" }
local KNOWN = {}
for _, k in ipairs(FS.KEYS) do KNOWN[k] = true end
FS.KNOWN = KNOWN

local GOLD100 = 100 * 10000 -- in copper
local PROF_TOPS = { 150, 225, 300 }

local function now() return GetServerTime and GetServerTime() or time() end

---------------------------------------------------------------------------
-- My own deeds and tallies
---------------------------------------------------------------------------
-- Kept for the fellowship you are in now, like the tallies: they start again in another one (kept for the character
-- for good, a fall in the first fellowship kept them from ever being first to fall in the next; code review of
-- 1 Nov 2026).
function FS:Mine()
  local f = F:Current()
  local fid, d = f and f.id or nil, ns.char.deeds
  if type(d) ~= "table" or d.fid ~= fid then d = { fid = fid }; ns.char.deeds = d end
  return d
end

local function share() if ns.Hero and F:Current() then ns.Hero:Soon("deeds", 3, function() ns.Hero:SendState() end) end end

-- Notes a deed the first time it happens. Returns true when it is new.
function FS:Note(key, t)
  if not KNOWN[key] then return false end
  local d = self:Mine()
  if d[key] then return false end
  d[key] = t or now()
  share()
  return true
end

-- The tallies count in the fellowship you are in now (they start again in another one).
function FS:Count(kind)
  local f = F:Current()
  if not f then return end
  local t = ns.char.tally
  if type(t) ~= "table" or t.fid ~= f.id then t = { fid = f.id }; ns.char.tally = t end
  t[kind] = (t[kind] or 0) + 1
  share()
end

-- How many runs the History holds with this Adventurer in them (all there was to go by before each counted their own).
function FS:HistoryRuns(f, name)
  local n = 0
  for _, e in ipairs(f.history or {}) do
    if e.type == "run" and type(e.names) == "table" then
      for _, x in ipairs(e.names) do if x == name then n = n + 1; break end end
    end
  end
  return n
end

-- I was in a dungeon run new to this addon (Fellowship/Clears.lua). Counted here like falls and quests, so every copy
-- shows the same count: the History keeps only its newest entries, and a copy passed on carries fewer. The first count
-- starts from what my History holds.
function FS:CountRun(f)
  if f ~= F:Current() then return end
  local t = ns.char.tally
  if type(t) ~= "table" or t.fid ~= f.id then t = { fid = f.id }; ns.char.tally = t end
  if t.runs == nil then t.runs = self:HistoryRuns(f, ns.Me()) end
  self:Count("runs")
end

-- What goes with my state: my deeds, and my tallies in this fellowship.
function FS:State()
  local f, t = F:Current(), ns.char and ns.char.tally
  local tally = (f and type(t) == "table" and t.fid == f.id) and { falls = t.falls, quests = t.quests, runs = t.runs } or nil
  local deeds = {}
  for k, v in pairs(self:Mine()) do if KNOWN[k] then deeds[k] = v end end -- (not the fellowship's id)
  return deeds, tally
end

---------------------------------------------------------------------------
-- The fellowship's firsts and tallies (from what every Adventurer shares)
---------------------------------------------------------------------------
-- The firsts of f, newest first: { key, name, time }. Ties go to the name first in the alphabet.
function FS:List(f)
  local out = {}
  for _, key in ipairs(self.KEYS) do
    local best, bt
    for name, m in pairs(f.members) do
      local h = f.heroes and f.heroes[name]
      local t = h and type(h.deeds) == "table" and tonumber(h.deeds[key])
      -- (Not a Friend of the fellowship's: the firsts are a race between the counted Adventurers, SPEC §1.1.)
      if t and not m.friend and (not m.joined or t >= m.joined - self.JOIN_SLACK) then
        if not bt or t < bt or (t == bt and name < best) then best, bt = name, t end
      end
    end
    if best then out[#out + 1] = { key = key, name = best, time = bt } end
  end
  table.sort(out, function(a, b)
    if a.time ~= b.time then return a.time > b.time end
    return a.key < b.key
  end)
  return out
end

-- "Brannic is the first to reach level 20."
function FS.Text(x) return (L["FIRST_" .. x.key:upper()] or x.key):format(ns.Short(x.name)) end

-- The firsts nobody has yet, in the order of KEYS (the Chronicle's "Still open" medals).
function FS:Open(f)
  local have, out = {}, {}
  for _, x in ipairs(self:List(f)) do have[x.key] = true end
  for _, key in ipairs(self.KEYS) do if not have[key] then out[#out + 1] = key end end
  return out
end

-- Who is closest to an open level first ("lvl30"): the counted Adventurer (not a Friend of the fellowship, not one of
-- the Fallen) with the highest level still below it, and that level; ties go to the name first in the alphabet. nil
-- for the other firsts (only levels are shared as they grow), or when nobody counted is below it.
function FS:Closest(f, key)
  local target = tonumber(key:match("^lvl(%d+)$"))
  if not target then return nil end
  local best, bl
  for name in pairs(f.members) do
    if not ns.Journey:Uncounted(f, name) then
      local lvl = ns.Hero:Level(f, name)
      if lvl < target and (not bl or lvl > bl or (lvl == bl and name < best)) then best, bl = name, lvl end
    end
  end
  return best, bl
end

-- The tallies: for each kind the Adventurer with the most (more than none), { kind, name, n, top, all }: top the
-- first three (the Chronicle's podium), all everyone with a count, most first (its tooltip). Ties go to the name first
-- in the alphabet. Each Adventurer counts their own (dungeon runs from the History for an addon that sends none).
function FS:Tallies(f)
  local counts = { falls = {}, runs = {}, quests = {} }
  for name in pairs(f.members) do
    local h = f.heroes and f.heroes[name]
    local t = h and type(h.tally) == "table" and h.tally or {}
    counts.falls[name], counts.quests[name] = tonumber(t.falls) or 0, tonumber(t.quests) or 0
    counts.runs[name] = tonumber(t.runs) or self:HistoryRuns(f, name)
  end
  local out = {}
  for _, kind in ipairs(self.TALLIES) do
    local all = {}
    for name, n in pairs(counts[kind]) do if n > 0 then all[#all + 1] = { name = name, n = n } end end
    table.sort(all, function(a, b)
      if a.n ~= b.n then return a.n > b.n end
      return a.name < b.name
    end)
    if #all > 0 then
      out[#out + 1] = { kind = kind, name = all[1].name, n = all[1].n, top = { all[1], all[2], all[3] }, all = all }
    end
  end
  return out
end

-- The Chronicle's entries for the firsts (UI/Pages/Chronicle.lua): like History entries, newest first.
function FS:Entries(f)
  local out = {}
  for _, x in ipairs(self:List(f)) do
    out[#out + 1] = { type = "first", icon = "first", time = x.time, text = self.Text(x), key = x.key, who = x.name }
  end
  return out
end

-- A new first seen by this addon: a toast when it happened within the hour (joining or updating brings no flood).
-- Seen ones are kept per character and fellowship.
function FS:Check(f)
  f = f or F:Current()
  if not f then return 0 end
  local seen = ns.char.firstsSeen
  if type(seen) ~= "table" or seen.fid ~= f.id then seen = { fid = f.id }; ns.char.firstsSeen = seen end
  local n = 0
  for _, x in ipairs(self:List(f)) do
    if seen[x.key] ~= x.name then
      seen[x.key] = x.name
      n = n + 1
      if now() - x.time <= self.RECENT then
        ns:Toast("first", L.T_FIRST:format(ns.Short(x.name)), self.Text(x), "chronicle")
      end
    end
  end
  if n > 0 then ns:Fire("FIRSTS") end
  return n
end

---------------------------------------------------------------------------
-- Noticing my own deeds
---------------------------------------------------------------------------
-- What I wear: the first rare (blue) and epic (purple) item.
function FS:CheckGear()
  if not ns.Hero then return end
  for _, g in pairs(ns.Hero:MyGear()) do
    if (g.q or 0) >= 4 then self:Note("epic") elseif (g.q or 0) == 3 then self:Note("rare") end
  end
end

-- Gold and PvP kills count from what the addon saw first, so a rich or seasoned character gets no first for the
-- past: only crossing 100 gold, or a kill after that, counts.
function FS:CheckMoney()
  local money = GetMoney and GetMoney() or 0
  local before = self.money
  self.money = money
  if before and before < GOLD100 and money >= GOLD100 then self:Note("gold100") end
end

function FS:CheckPvP()
  if not GetPVPLifetimeStats then return end
  local kills = tonumber((GetPVPLifetimeStats())) or 0
  if ns.char.pvpBase == nil then ns.char.pvpBase = kills return end
  if kills > ns.char.pvpBase then self:Note("pvp") end
end

-- A profession passing 150, 225 or 300 (the skill this addon saw first is the start).
function FS:CheckProfessions()
  if not (GetProfessions and GetProfessionInfo) then return end
  ns.char.profSeen = type(ns.char.profSeen) == "table" and ns.char.profSeen or {}
  local p1, p2 = GetProfessions()
  for _, i in ipairs({ p1, p2 }) do
    local name, _, skill = GetProfessionInfo(i)
    skill = tonumber(skill)
    if name and skill then
      local was = ns.char.profSeen[name]
      if was then
        for _, top in ipairs(PROF_TOPS) do if was < top and skill >= top then self:Note("prof" .. top) end end
      end
      ns.char.profSeen[name] = skill
    end
  end
end

function FS:CheckMount()
  if IsMounted and IsMounted() then self:Note("mount") end
end

-- My death: the first to fall, the tally, and "FELL" for a survival challenge (Fellowship/Challenges.lua records it
-- in the fellowship). The only place the addon notices a death.
function FS:Fell()
  self:Note("fall")
  self:Count("falls")
  ns:Fire("FELL")
end

ns:On("LOGIN", function()
  FS.money = GetMoney and GetMoney() or 0
  C_Timer.After(8, function()
    FS:CheckGear(); FS:CheckMount(); FS:CheckPvP(); FS:CheckProfessions()
    FS:Check()
  end)
end)
ns:RegisterEvent("PLAYER_LEVEL_UP", function(_, level)
  level = tonumber(level)
  if level and level % 10 == 0 and level >= 10 and level <= 60 then FS:Note("lvl" .. level) end
end)
ns:RegisterEvent("PLAYER_DEAD", function() FS:Fell() end)
ns:RegisterEvent("QUEST_TURNED_IN", function() FS:Count("quests") end)
ns:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function() FS:CheckGear() end)
ns:RegisterEvent("PLAYER_MONEY", function() FS:CheckMoney() end)
ns:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", function() FS:CheckMount() end)
ns:RegisterEvent("PLAYER_PVP_KILLS_CHANGED", function() FS:CheckPvP() end)
ns:RegisterEvent("SKILL_LINES_CHANGED", function() FS:CheckProfessions() end)
-- Another Adventurer's deeds arrive with their state.
ns:On("HEROES", function() FS:Check() end)
