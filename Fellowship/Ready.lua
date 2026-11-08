-- Who is ready for a dungeon (U98-U100, the owner's grilling of 8 Nov 2026). Ready (QuestLists:Ready): every
-- Start-early chain done up to the dungeon quest and every Pick-up quest in the log or done, read from each
-- Adventurer's shared quest log, so it is only as fresh as their last word ("as of" when they are offline).
-- Toasts, never in combat (after it): "Ready for the Deadmines" (yours, once per dungeon of your chapter) and "Everyone
-- is ready for the Deadmines" (once per dungeon, when every Adventurer counted for the chapter is). Each copy works
-- them out from the same logs, so everyone sees each once; no message is needed.
-- Remind (op "remind" {name, key}): any member, a Friend of the fellowship too, reminds an online Adventurer who is not
-- ready. Once per Adventurer, dungeon and day by anyone (the day of the change's server time, so every copy agrees,
-- also when it arrives late). Reminders are kept two days.
local _, ns = ...
local L = ns.L
local F = ns.Fellowship
local R = { WAIT = 1, KEEP = 2 * 86400 }
ns.Ready = R

local function day(t) return date("!%Y%m%d", t) end
local function now() return GetServerTime and GetServerTime() or time() end

-- One row per Adventurer counted for the chapter, you first: { name, r (QuestLists:Ready; nil: nothing to get
-- ready), online }.
function R:Rows(f, key)
  local me, out = ns.Me(), {}
  for _, n in ipairs(ns.Journey:Counted(f)) do
    local row = { name = n, r = ns.QuestLists:Ready(f, key, n), online = ns.Hero:Online(f, n) }
    if n == me then table.insert(out, 1, row) else out[#out + 1] = row end
  end
  return out
end

-- How far: the share of what is ready (0 to 1), and how many quests are still to pick up or start.
function R.Share(r)
  if not r then return 0, 0 end
  local of = r.earlyOf + r.pickOf
  return (r.early + r.pick) / of, of - r.early - r.pick
end

-- "Edstromar  ·  Start early ✓  ·  Picked up 2 of 4" (the check as the game's ready-check mark).
function R.Line(name, r)
  local parts = { ns.Short(name) }
  if r and r.earlyOf > 0 then
    parts[#parts + 1] = r.early == r.earlyOf and L.RD_EARLY_DONE:format("|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t")
      or L.RD_EARLY_N:format(r.early, r.earlyOf)
  end
  if r and r.pickOf > 0 then parts[#parts + 1] = L.RD_PICKED:format(r.pick, r.pickOf) end
  if not r then parts[#parts + 1] = L.RD_NOTHING end
  return table.concat(parts, "  ·  ")
end

-- Every Adventurer counted for the chapter is ready (two at least: alone, your own toast says it).
function R:Everyone(f, key)
  local list = ns.Journey:Counted(f)
  if #list < 2 then return false end
  for _, n in ipairs(list) do
    local r = ns.QuestLists:Ready(f, key, n)
    if not (r and r.ready) then return false end
  end
  return true
end

---------------------------------------------------------------------------
-- The toasts
---------------------------------------------------------------------------
-- The dungeons of your chapter not cleared yet (the journey's later ones would toast long before they matter).
function R:Watched(f)
  local J, out = ns.Journey, {}
  local cur = J:CurrentIndex(f)
  if not f.journey.chapters[cur] then return out end
  for _, x in ipairs(J:ChapterList(f, cur)) do
    if J:DungeonState(f, cur, x) ~= "cleared" then out[#out + 1] = x end
  end
  return out
end

function R:Check()
  local f = F:Current()
  if not f or f.sample or not f.members[ns.Me()] then return end
  if ns.Combat:InCombat() then
    if not self.later then self.later = true; ns.Combat:AfterCombat(function() R.later = nil; R:Check() end) end
    return
  end
  ns.char.readyToasts = type(ns.char.readyToasts) == "table" and ns.char.readyToasts or {}
  local seen = ns.char.readyToasts[f.id] or {}
  ns.char.readyToasts[f.id] = seen
  for _, x in ipairs(self:Watched(f)) do
    local key, name = x.key, x.d[2]
    local mine = ns.QuestLists:Ready(f, key, ns.Me())
    if mine and mine.ready and not seen[key] then
      seen[key] = true
      ns:Toast("dready", L.T_READY, L.T_READY_TEXT:format(name), function() R:Open(key) end, { dungeon = key })
    end
    if not seen["all:" .. key] and self:Everyone(f, key) then
      seen["all:" .. key] = true
      ns:Toast("dallready", L.T_ALL_READY, L.T_ALL_READY_TEXT:format(name), function() R:Open(key) end, { dungeon = key })
    end
  end
end

function R:Soon()
  if self.soon then return end
  self.soon = true
  C_Timer.After(self.WAIT, function() R.soon = nil; R:Check() end)
end

function R:Open(key) if ns.DungeonPage then ns.DungeonPage:Open(key) end end

---------------------------------------------------------------------------
-- Remind
---------------------------------------------------------------------------
-- The reminder name had for a dungeon on the day of at (server time; now when nil): { by, t }, or nil.
function R:Reminded(f, name, key, at)
  local x = f.reminds and f.reminds[name] and f.reminds[name][key]
  if x and day(x.t) == day(at or now()) then return x end
  return nil
end

-- Why name can't be reminded now, or nil: "self", "offline", "ready" (or nothing to get ready), "today" (and who),
-- "off" (they turned reminders off).
function R:CanRemind(f, name, key)
  if name == ns.Me() then return "self" end
  local x = self:Reminded(f, name, key)
  if x then return "today", x.by end
  local r = ns.QuestLists:Ready(f, key, name)
  if not r or r.ready then return "ready" end
  if not ns.Hero:Online(f, name) then return "offline" end
  local h = ns.Hero:Get(f, name)
  if h and h.noRemind then return "off" end
  return nil
end

-- Sends a reminder (op "remind"); a toast says why not when it can't go.
function R:Remind(name, key)
  local f = F:Current()
  if not f then return false end
  local why, by = self:CanRemind(f, name, key)
  if why == "off" then ns:Toast(nil, L.REMIND_TITLE, L.REMIND_OFF:format(ns.Short(name))) return false end
  if why == "today" then ns:Toast(nil, L.REMIND_TITLE, L.REMIND_TODAY:format(ns.Short(by))) return false end
  if why then return false end
  return F:Do({ k = "remind", name = name, key = key })
end

function R:Apply(f, by, op, t)
  local name, key = op.name, op.key
  if not f.members[by] or type(name) ~= "string" or not f.members[name] or name == by then return false end
  if type(key) ~= "string" or not ns.Dungeon(key) then return false end
  local st = tonumber(op.st) or t
  -- Reminded already that day (two at once, from two copies), or a newer one is here (one from an earlier day that
  -- arrived late): the first of the day stays, and the change still counts, so the copies keep the same version (the
  -- review of 8 Nov 2026; Entrances:Apply does the same).
  local had = f.reminds and f.reminds[name] and f.reminds[name][key]
  if had and (day(had.t) == day(st) or had.t > st) then return true end
  f.reminds = f.reminds or {}
  f.reminds[name] = f.reminds[name] or {}
  f.reminds[name][key] = { by = by, t = st }
  -- (Fresh by the server's clock on both sides: the sender's PC clock may be off.)
  if name == ns.Me() and not f.sample and now() - st <= ns.Challenges.RECENT then
    -- Quests to pick up, or else chains to start early (a chain not started is no quest to pick up).
    local r = ns.QuestLists:Ready(f, key, name)
    local pick, early = r and r.pickOf - r.pick or 0, r and r.earlyOf - r.early or 0
    if pick + early > 0 then
      local where = ns.Dungeon(key)[2]:gsub(L.REMIND_ARTICLE, "")
      local who = ns.Short(by)
      local text = pick == 0 and L.REMIND_EARLY:format(who, where)
        or (pick == 1 and L.REMIND_1:format(who, where) or L.REMIND_N:format(who, pick, where))
      ns:Toast("dremind", L.REMIND_TITLE, text, function() R:Open(key) end, { dungeon = key, who = by })
    end
  end
  return true
end

-- Old reminders go (a copy keeps two days of them).
function R:Sanitize(f)
  if type(f.reminds) ~= "table" then f.reminds = nil return end
  local out, cut = {}, now() - self.KEEP
  for name, list in pairs(f.reminds) do
    if type(name) == "string" and type(list) == "table" then
      for key, x in pairs(list) do
        if type(key) == "string" and type(x) == "table" and type(x.by) == "string" and tonumber(x.t) and tonumber(x.t) >= cut then
          out[name] = out[name] or {}
          out[name][key] = { by = x.by, t = tonumber(x.t) }
        end
      end
    end
  end
  f.reminds = next(out) and out or nil
end

ns:On("HEROES", function() R:Soon() end)
-- Reminders turned off or on: the others hear it with your state (they are told before they send one).
ns:On("SETTING", function(key)
  if key == "toasts" and F:Current() then ns.Hero:Soon("remind", 3, function() ns.Hero:SendState() end) end
end)
ns:On("LOGIN", function() C_Timer.After(8, function() R:Check() end) end)
