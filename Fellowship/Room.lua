-- Room for the dungeon quests (U78, SPEC §4.2): the level the current chapter's dungeon quests and the dungeons' mobs
-- would take an Adventurer to, and, when that goes past the cap (with its allowance), where to stop questing elsewhere
-- so they still fit. It counts exactly two things (the owner, 7 Nov 2026): the XP of the chapter's dungeon quests not
-- done yet (picked up or not), and the dungeons' mob XP learned from the fellowship's own runs (Settings can leave the
-- mobs out).
--   MOBXP  { fid, k (dungeon), l (level at the run), xp }: one run's mob XP, so one run teaches everyone.
local _, ns = ...
local L = ns.L
local F, Hr, QL = ns.Fellowship, ns.Hero, ns.QuestLists
local R = { SOON = 0.5 }
ns.Room = R

-- A quest's XP: from the game for one in my log, else learned, harvested or shipped (U79's data); nil when unknown.
function R.QuestXP(id, inMyLog)
  if inMyLog and GetQuestLogRewardXP then
    local ok, xp = pcall(GetQuestLogRewardXP, id)
    if ok and not ns.Secret(xp) and tonumber(xp) and xp > 0 then return xp end
  end
  local harvested = ns.QUEST_CHAINS and ns.QUEST_CHAINS.xp and ns.QUEST_CHAINS.xp[id]
  local ship = ns.QUEST_STARTS[id] and ns.QUEST_STARTS[id].xp
  return ns.db.questXP and ns.db.questXP[id] or harvested or ship
end

-- A dungeon's mob XP at a level: the run nearest that level (ns.db.mobXP[base][level] = xp), or nil before any run.
-- shortcut: not scaled between levels (kill XP grows with the mobs' level and shrinks for grey ones); fine within the
-- few levels a chapter spans.
function R.MobXP(key, level)
  local runs = ns.db.mobXP and ns.db.mobXP[ns.BaseKey(key)]
  local best, gap
  for l, xp in pairs(runs or {}) do
    local d = math.abs(l - level)
    if not gap or d < gap then best, gap = xp, d end
  end
  return best
end

-- An Adventurer's level, XP and level size as the book shows them: live for the character I play (so the warnings
-- do not wait for the next shared state), else as shared. A pretend level (/jtf debug level) and the tour's sample
-- keep their own, like every other page (the check of 7 Nov 2026 showed level 1 here and 22 everywhere else). nil
-- without a level size (at the level cap) or when the game keeps it secret.
local function standing(f, name)
  local h = Hr:Get(f, name) or {}
  local level, xp, max = h.level, h.xp, h.xpMax
  if name == ns.Self() and not (ns.Dev and ns.Dev.myLevel) and not f.sample then
    level, xp, max = UnitLevel("player"), UnitXP("player"), UnitXPMax("player")
  end
  if not (level and max) or ns.Secret(xp) or ns.Secret(max) or max <= 0 then return nil end
  return level, ns.Clamp(xp or 0, 0, max), max
end

-- gain XP in levels for an Adventurer, from where they stand, level by level (Pace.Reach); nil without a level size.
function R:Levels(f, name, gain)
  local level, xp, max = standing(f, name)
  return level and ns.Pace.Reach(level, xp, max, gain) - (level + xp / max) or nil
end

-- One dungeon's share for an Adventurer: { quests (XP of the quests not done), unknown (quests whose XP nobody knows),
-- mobs (XP; nil before the fellowship has run it, 0 once cleared or with the mobs left out) }.
function R:Share(f, key, name)
  local h = Hr:Get(f, name) or {}
  local me = name == ns.Self()
  local out = { quests = 0, unknown = 0, mobs = 0 }
  for _, q in ipairs(QL:DungeonQuests(f, key)) do
    if not (h.questsDone and h.questsDone[q.id]) then
      local xp = R.QuestXP(q.id, me and h.quests and h.quests[q.id] ~= nil)
      if xp then out.quests = out.quests + xp else out.unknown = out.unknown + 1 end
    end
  end
  if ns.Settings:Get("roomMobs") ~= false and not ns.Journey:Cleared(f, key) then
    out.mobs = R.MobXP(key, (standing(f, name)) or 1)
  end
  return out
end

-- The current chapter for an Adventurer: { now, levels, to, cap, limit, stop (shown from half a level before it; nil
-- with more room), quests, mobs (in levels), unknown, unrun (dungeons whose mobs nobody knows yet), n }. nil without
-- a chapter, a level size (at the level cap) or any XP known to count (no "about 0.0 levels" line).
-- Levels are walked one by one with the game's XP table (Pace.Reach, Pace.Back): each is bigger than the last.
function R:Chapter(f, name)
  local J = ns.Journey
  local ch = f and J:Current(f)
  local level, xp, max = standing(f, name)
  if not (ch and level) then return nil end
  local quests, mobs, unknown, unrun = 0, 0, 0, 0
  for _, x in ipairs(J:ChapterList(f, ch.n)) do
    if not x.early then
      local s = self:Share(f, x.key, name)
      quests, unknown = quests + s.quests, unknown + s.unknown
      if s.mobs then mobs = mobs + s.mobs else unrun = unrun + 1 end
    end
  end
  if quests + mobs <= 0 then return nil end
  local Pa = ns.Pace
  local now = level + xp / max
  local qTo, to = Pa.Reach(level, xp, max, quests), Pa.Reach(level, xp, max, quests + mobs)
  local limit = ch.cap + f.rules.capTol
  return { now = now, levels = to - now, to = to, cap = ch.cap, tol = f.rules.capTol, limit = limit,
    stop = to > limit - R.SOON and Pa.Back(limit, quests + mobs, level, max) or nil, quests = qTo - now, mobs = to - qTo,
    unknown = unknown, unrun = unrun, n = ch.n }
end

-- In words: "The dungeon quests here: about 1.4 levels, to 27.4 of the cap 28." and, when they would not fit, "Stop
-- questing at 26.6 to leave room for them."; then the notes (mobs, quests whose XP is not known yet).
local function one(v) return math.floor(v * 10 + 0.5) / 10 end
function R.Lines(r)
  local cap = r.tol > 0 and L.ROOM_CAP_TOL:format(r.cap, r.tol) or L.ROOM_CAP:format(r.cap)
  local main = L.ROOM_LINE:format(one(r.levels), one(r.to), cap)
  local stop = r.stop and L.ROOM_STOP:format(one(math.max(r.stop, 1))) or nil
  local notes = {}
  if ns.Settings:Get("roomMobs") == false then notes[1] = L.ROOM_MOBS_OFF
  elseif r.unrun > 0 then notes[1] = L.ROOM_MOBS_UNKNOWN
  else notes[1] = L.ROOM_MOBS:format(one(r.mobs)) end
  if r.unknown > 0 then notes[#notes + 1] = r.unknown == 1 and L.ROOM_UNKNOWN_1 or L.ROOM_UNKNOWN_N:format(r.unknown) end
  return main, stop, table.concat(notes, "  ")
end
R.One = one

---------------------------------------------------------------------------
-- The two warnings: half a level before the stop point, and at it (once each per chapter)
---------------------------------------------------------------------------
function R:Check()
  local f = F:Current()
  local r = f and self:Chapter(f, ns.Me())
  if not (r and r.stop) then return end
  local stop = r.stop
  ns.char.roomToasted = type(ns.char.roomToasted) == "table" and ns.char.roomToasted or {}
  local key = f.id .. ":" .. r.n
  local stage = ns.char.roomToasted[key] or 0
  if r.now >= stop and stage < 2 then
    ns.char.roomToasted[key] = 2
    ns:Toast("room", L.TOAST_ROOM_NOW_TITLE, L.TOAST_ROOM_NOW, "overview")
  elseif r.now >= stop - self.SOON and stage < 1 then
    ns.char.roomToasted[key] = 1
    ns:Toast("room", L.TOAST_ROOM_SOON_TITLE, L.TOAST_ROOM_SOON:format(one(math.max(stop, 1))), "overview")
  end
end

---------------------------------------------------------------------------
-- Mob XP from the fellowship's runs: in a dungeon of the journey, the XP gained there minus quest hand-ins and the
-- rested bonus (rested doubles kill XP; the rested XP used is that bonus), kept for the dungeon and the level the run
-- began at when the player leaves (the best run at that level), and shared.
-- In an instance several dungeons share (Scarlet Monastery's wings, Dire Maul), the first boss down says which one
-- it was; a run there with no boss down is not kept.
-- shortcut: a /reload inside the dungeon starts the count again; the run then counts less, and the best run stays.
---------------------------------------------------------------------------
local function xpNow()
  local l, x, m = UnitLevel("player"), UnitXP("player"), UnitXPMax("player")
  local rest = GetXPExhaustion and GetXPExhaustion()
  if ns.Secret(x) or ns.Secret(m) or ns.Secret(rest) then return nil end
  return l, x, m, tonumber(rest) or 0
end

function R:Keep(key, level, xp)
  key, level, xp = ns.BaseKey(key), tonumber(level), tonumber(xp)
  if not (key and ns.Dungeon(key) and level and level >= 1 and level <= 100 and xp and xp > 0 and xp < 1000000) then
    return false
  end
  ns.db.mobXP = ns.db.mobXP or {}
  local runs = ns.db.mobXP[key] or {}
  ns.db.mobXP[key] = runs
  level, xp = math.floor(level), math.floor(xp)
  if (runs[level] or 0) >= xp then return false end
  runs[level] = xp
  return true
end

function R:OnXP()
  local run = self.run
  local l, x, m, rest = xpNow()
  if not (run and l) then return end
  local gain = 0
  if l == run.l then gain = x - run.x elseif l == run.l + 1 then gain = (run.m - run.x) + x end
  if gain > 0 then run.gain = run.gain + gain end
  if rest < run.rest then run.rested = run.rested + (run.rest - rest) end
  run.l, run.x, run.m, run.rest = l, x, m, rest
end

function R:OnZone()
  local inside, kind = IsInInstance()
  if inside and kind == "party" then
    if self.run then return end
    local iname, _, _, _, _, _, _, instID = GetInstanceInfo()
    if ns.Secret(iname) then iname = nil end
    if ns.Secret(instID) then instID = nil end
    local keys = ns.Clears:KeysHere(instID, iname)
    local l, x, m, rest = xpNow()
    if keys[1] and l then
      self.run = { key = keys[1], keys = #keys > 1 and keys or nil, start = l, l = l, x = x, m = m, rest = rest, rested = 0,
        gain = 0, quests = 0 }
    end
  elseif self.run then
    local run = self.run
    self.run = nil
    if run.keys then return end
    local mob = run.gain - run.quests - run.rested
    local f = F:Current()
    if self:Keep(run.key, run.start, mob) and f then
      ns.Comm:SendAll(ns.Others(f), "MOBXP", { fid = f.id, k = run.key, l = run.start, xp = mob })
    end
  end
end

-- A boss down in an instance several dungeons share: its dungeon is the run's.
function R:OnBoss(encounterID, name)
  local run = self.run
  if not (run and run.keys) then return end
  if ns.Secret(encounterID) then encounterID = nil end
  if ns.Secret(name) then name = nil end
  for _, key in ipairs(run.keys) do
    local mine, all = ns.Clears:DataBosses(key)
    if mine and #mine < #all then
      for _, b in ipairs(mine) do
        if (encounterID and b.id == encounterID) or (name and b.name == name) then run.key, run.keys = key, nil return end
      end
    end
  end
end

ns:RegisterEvent("PLAYER_XP_UPDATE", function()
  R:OnXP()
  if not R.checking then
    R.checking = true
    C_Timer.After(2, function() R.checking = nil; R:Check() end)
  end
end)
ns:RegisterEvent("QUEST_TURNED_IN", function(_, _, xp)
  if R.run and not ns.Secret(xp) and tonumber(xp) then R.run.quests = R.run.quests + xp end
end)
ns:RegisterEvent("ENCOUNTER_END", function(_, encounterID, name, _, _, success)
  if not ns.Secret(success) and (success == 1 or success == true) then R:OnBoss(encounterID, name) end
end)
ns:RegisterEvent("PLAYER_ENTERING_WORLD", function() R:OnZone() end)
ns:RegisterEvent("ZONE_CHANGED_NEW_AREA", function() R:OnZone() end)

ns.Comm:On("MOBXP", function(sender, d)
  if type(d) ~= "table" or type(d.k) ~= "string" then return end
  local f = F:Get(d.fid)
  if f and f.members[sender] and not ns.Secret(d.xp) then R:Keep(d.k, d.l, d.xp) end
end)
