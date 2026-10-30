-- The rules at work (SPEC §2, §3, §5): leader takeover, the cap warning, over-the-cap history and progress toasts.
-- Every client watches the fellowship (FELLOWSHIP and HEROES events) and compares it with what it saw last:
--   a chapter unlocks, everyone reaches the floor, a Hero reaches the floor or the cap, a Hero goes over the cap.
-- The first look after login only remembers, so nothing old is shown again.
local _, ns = ...
local L = ns.L
local F, J, Hr = ns.Fellowship, ns.Journey, ns.Hero
local P = { warned = {} }
ns.Progress = P

local DAY = 86400

---------------------------------------------------------------------------
-- Leader takeover
---------------------------------------------------------------------------
-- The Adventurer who has been in the fellowship the longest and is not away (ties: by name). (It was the longest-
-- serving Steward until the two ranks of 27 Oct 2026.)
function P:LongestServing(f)
  local best, since
  for name, m in pairs(f.members) do
    local t = tonumber(m.joined) or 0
    if name ~= f.leader and not ns.Journey:Away(f, name) and (not best or t < since or (t == since and name < best)) then
      best, since = name, t
    end
  end
  return best
end

-- May `by` take over as leader? The rule allows it, `by` is the longest-serving Adventurer, and the leader has not
-- been seen for the rule's number of days (as far as this client knows).
function P:CanTakeOver(f, by)
  local r = f.rules
  if r.takeoverNever or by == f.leader or self:LongestServing(f) ~= by then return false end
  return time() - Hr:LastSeen(f, f.leader) > (r.takeover or 14) * DAY
end

function P:CheckTakeover(f)
  if self:CanTakeOver(f, ns.Me()) then F:Do({ k = "takeover" }) end
end

---------------------------------------------------------------------------
-- Standing of each counted Hero in the current chapter
---------------------------------------------------------------------------
local function standing(f, ch, name)
  local lvl, r = Hr:Level(f, name), f.rules
  if lvl < ch.floor - r.floorTol then return "below" end
  if lvl > ch.cap + r.capTol then return "over" end
  if lvl >= ch.cap then return "cap" end
  return "ready"
end

-- In a fellowship run: in a dungeon or raid with enough Heroes in the group, or a help run (levels from runs may
-- pass the cap).
function P:InRun(f)
  local _, itype = GetInstanceInfo()
  if (itype == "party" or itype == "raid") and #ns.Clears:GroupHeroes(f) >= f.rules.minHeroes then return true end
  return self:HelpRun(f)
end

-- A help run (SPEC §6): grouped with a Hero who is below the floor of the current chapter.
function P:HelpRun(f)
  local below = {}
  for _, name in ipairs(J:Below(f, J:CurrentIndex(f))) do below[name] = true end
  for _, name in ipairs(ns.Clears:GroupHeroes(f)) do
    if name ~= ns.Me() and below[name] then return true end
  end
  return false
end

-- Over the cap: written to the history once per Hero and level, unless fellowship runs allowed it.
function P:OverCap(f, ch, n, name)
  local lvl, r = Hr:Level(f, name), f.rules
  f.capLogged = f.capLogged or {}
  if lvl <= ch.cap + r.capTol or lvl <= (f.capLogged[name] or 0) then return end
  local h = Hr:Get(f, name)
  local inRun = h and h.run
  if inRun and r.runXp and lvl <= ch.cap + r.capTol + r.runXpMax then return end
  f.capLogged[name] = lvl
  ns.Clears:Log(f, { type = "cap", icon = "cap", ok = false,
    text = (inRun and L.H_OVER_CAP_RUN or L.H_OVER_CAP):format(ns.Short(name), lvl, ns.Journey.Roman(n), ch.cap) })
end

---------------------------------------------------------------------------
-- Watching for changes
---------------------------------------------------------------------------
function P:Check(f)
  local cur = J:CurrentIndex(f)
  local ch = f.journey.chapters[cur]
  local unlocked = ch ~= nil and J:Unlocked(f)
  local stand = {}
  if ch then
    for _, name in ipairs(J:Counted(f)) do
      stand[name] = standing(f, ch, name)
      self:OverCap(f, ch, cur, name)
    end
  end
  local s = self.snap
  -- The journey is complete: the biggest moment of all.
  if s and s.fid == f.id and not ch and s.cur <= #f.journey.chapters then
    ns:Toast("journey", L.T_JOURNEY, L.T_JOURNEY_TEXT:format(f.name))
  end
  if s and s.fid == f.id and ch then
    if cur > s.cur then
      ns:Toast("chapter", L.T_CHAPTER:format(ns.Journey.Roman(cur)), L.T_CHAPTER_TEXT:format(ch.name, ch.floor, ch.cap), "chapter")
    else
      if unlocked and not s.unlocked then ns:Toast("floor", L.T_FLOOR, L.T_FLOOR_TEXT:format(ns.Journey.Roman(cur)), "chapter") end
      local below = J:Below(f, cur)
      for name, st in pairs(stand) do
        local old = s.stand[name]
        if old and old ~= st then
          local lvl = Hr:Level(f, name)
          -- About yourself the toast says "You" (seen in game: your own name read oddly).
          local mine = name == ns.Me()
          if old == "below" and st ~= "below" and #below > 0 then
            ns:Toast("heroFloor", mine and L.T_YOU_FLOOR or L.T_HERO_FLOOR:format(ns.Short(name)), L.T_HERO_FLOOR_TEXT:format(lvl, J.Names(f, below)))
          end
          if st == "cap" and (old == "below" or old == "ready") then
            ns:Toast("heroCap", mine and L.T_YOU_CAP or L.T_HERO_CAP:format(ns.Short(name)), L.T_HERO_CAP_TEXT:format(lvl))
          end
          if st == "over" then
            ns:Toast("overCap", mine and L.T_YOU_OVER or L.T_OVER_CAP:format(ns.Short(name)), L.T_OVER_CAP_TEXT:format(lvl, ch.cap, f.rules.capTol))
          end
        end
      end
    end
  end
  -- You pull ahead (M25): after a level up, at least AHEAD levels above a counted Adventurer; once per level.
  local mine = Hr:Level(f, ns.Me())
  if s and s.fid == f.id and ch and s.mine and mine > s.mine then
    local who, gap = self:Ahead(f)
    if who and not self.warned["ahead:" .. mine] then
      self.warned["ahead:" .. mine] = true
      ns:Toast("ahead", L.T_AHEAD:format(gap, ns.Short(who)), L.T_AHEAD_TEXT:format(ns.Short(who)), "overview")
    end
  end
  self.snap = { fid = f.id, cur = cur, unlocked = unlocked, stand = stand, mine = mine }
  self:WarnCap(f, ch)
end

-- The Adventurer you are furthest ahead of, and by how many levels, when it is AHEAD or more: counted (not away),
-- not catching up (a newcomer far below is not one you left behind). Nil otherwise.
P.AHEAD = 2
function P:Ahead(f)
  local me = ns.Me()
  local mine, who, gap = Hr:Level(f, me), nil, 0
  for _, name in ipairs(J:Counted(f)) do
    if name ~= me and not J:CatchingUp(f, name) then
      local d = mine - Hr:Level(f, name)
      if d > gap or (d == gap and who and name < who) then who, gap = name, d end
    end
  end
  if who and gap >= self.AHEAD then return who, gap end
  return nil
end

---------------------------------------------------------------------------
-- The cap warning (Settings: Warn before the cap, at a share of the last level's XP)
---------------------------------------------------------------------------
-- "close" (the level before the cap, past the warning point), "at" (at or over the cap), or nil.
function P:CapState(f, ch)
  ch = ch or J:Current(f)
  if not ch or not ns.Settings:Get("warnCap") then return nil end
  local lvl = Hr:Level(f, ns.Me())
  if lvl >= ch.cap then return "at" end
  local max = UnitXPMax("player") or 0
  if lvl == ch.cap - 1 and max > 0 and (UnitXP("player") or 0) / max * 100 >= ns.Settings:Get("warnPct") then return "close" end
  return nil
end

function P:WarnCap(f, ch)
  ch = ch or J:Current(f)
  local st = self:CapState(f, ch)
  local key = st and (st .. ":" .. Hr:Level(f, ns.Me()))
  if not st or self.warned[key] then return end
  self.warned[key] = true
  ns:Print(st == "at" and L.WARN_AT_CAP or L.WARN_CLOSE:format(ch and ch.cap or 0), true)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local function check()
  local f = F:Current()
  if f then P:Check(f) end
end
ns:On("FELLOWSHIP", check)
ns:On("HEROES", check)
ns:On("JOINED", function() P.snap = nil; check() end)
ns:RegisterEvent("PLAYER_XP_UPDATE", function()
  local f = F:Current()
  if f then P:WarnCap(f) end
end)
ns:On("LOGIN", function()
  local function takeover() local f = F:Current(); if f then P:CheckTakeover(f) end end
  C_Timer.After(20, takeover)
  C_Timer.NewTicker(Hr.HEARTBEAT, takeover)
end)
