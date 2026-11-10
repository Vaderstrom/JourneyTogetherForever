-- Room for the dungeon quests (U78, SPEC §4.4): the level the current chapter's dungeon quests would take an
-- Adventurer to, and, when that goes past the start of the cap level (with its allowance), where to stop questing
-- elsewhere so they still fit. Only the XP of the chapter's dungeon quests not done yet counts (picked up or not); the
-- cap level itself is left for the dungeons' mobs, since only a level above it is over the cap (the owner, 10 Nov 2026:
-- "Leave mobs out"; nothing public has WoW Forever's mob XP, and the runs' own figure came only after the first run).
-- Older versions send MOBXP (a run's mob XP): it has no handler and is dropped.
local _, ns = ...
local L = ns.L
local F, Hr, QL = ns.Fellowship, ns.Hero, ns.QuestLists
local R = { SOON = 0.5 }
ns.Room = R

-- A quest's XP. First the game's own (WoW Forever's, at my level; the owner, 8 Nov 2026: from the game, not from
-- other sites): for a quest in my log, or for any quest once the game has loaded it, asked once per session (the
-- book redraws when it arrives). Else our data's (Data/DungeonQuests.lua; a chain step's comes as fallback); nil when
-- unknown.
-- shortcut: the game's number is for my level, also on another Adventurer's card; within a chapter's few levels it
-- is the same (quest XP only drops for a player far above the quest).
R.asked = {}
function R.QuestXP(id, fallback)
  if GetQuestLogRewardXP then
    local ok, xp = pcall(GetQuestLogRewardXP, id)
    if ok and not ns.Secret(xp) and tonumber(xp) and xp > 0 then return xp end
    if not R.asked[id] and C_QuestLog and C_QuestLog.RequestLoadQuestByID then
      R.asked[id] = true
      pcall(C_QuestLog.RequestLoadQuestByID, id)
      if C_TaskQuest and C_TaskQuest.RequestPreloadRewardData then pcall(C_TaskQuest.RequestPreloadRewardData, id) end
    end
  end
  return ns.QUEST_STARTS[id] and ns.QUEST_STARTS[id].xp or fallback
end

ns:RegisterEvent("QUEST_DATA_LOAD_RESULT", function(_, id, ok)
  if not (ok and R.asked[id]) then return end
  if ns.Window and ns.Window.RefreshSoon then ns.Window:RefreshSoon() end
  if ns.Tracker then ns.Tracker:RefreshSoon() end -- its room line; the book's RefreshSoon skips while it is closed
end)

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

-- One dungeon's share for an Adventurer: { quests (XP of the quests not done), unknown (quests whose XP nobody knows) }.
-- seen: quests counted already, for a chapter whose dungeons share one (Scarlet Monastery's wings), so it counts once.
function R:Share(f, key, name, seen)
  local h = Hr:Get(f, name) or {}
  local out = { quests = 0, unknown = 0 }
  seen = seen or {}
  local function count(id, xp)
    if h.questsDone and h.questsDone[id] or seen[id] then return end
    seen[id] = true
    xp = R.QuestXP(id, xp)
    if xp then out.quests = out.quests + xp else out.unknown = out.unknown + 1 end
  end
  for _, q in ipairs(QL:DungeonQuests(f, key)) do
    count(q.id)
    -- A step of its chain done in the run pays there too (Destruction in Deadmines' explosives, before Alba's quest).
    local st = ns.QUEST_STARTS[q.id]
    for _, s in ipairs(st and st.after or {}) do if s.run then count(s[1], s.xp) end end
  end
  return out
end

-- The current chapter for an Adventurer: { now, levels, to, cap, tol, limit (the start of the cap level, with its
-- allowance), stopAt, stop (shown from half a level before it; nil with more room), unknown, n }. nil without a
-- chapter, a level size (at the level cap) or any quest XP known (no "about 0.0 levels" line).
-- Levels are walked one by one with the game's XP table (Pace.Reach, Pace.Back): each is bigger than the last.
function R:Chapter(f, name)
  local J = ns.Journey
  local ch = f and J:Current(f)
  local level, xp, max = standing(f, name)
  if not (ch and level) then return nil end
  local quests, unknown, seen = 0, 0, {}
  for _, x in ipairs(J:ChapterList(f, ch.n)) do
    if not x.early then
      local s = self:Share(f, x.key, name, seen)
      quests, unknown = quests + s.quests, unknown + s.unknown
    end
  end
  if quests <= 0 then return nil end
  local Pa = ns.Pace
  local now = level + xp / max
  local to = Pa.Reach(level, xp, max, quests)
  local limit = ns.Journey:CapLevel(f, ch)
  local stopAt = Pa.Back(limit, quests, level, max)
  return { now = now, levels = to - now, to = to, cap = ch.cap, tol = f.rules.capTol, limit = limit, stopAt = stopAt,
    stop = to > limit - R.SOON and stopAt or nil, unknown = unknown, n = ch.n }
end

-- In words: "The dungeon quests here: about 1.4 levels, to 27.4 of the cap 28." and, when they would not fit, "Stop
-- questing at 26.6 to leave room for them."; then the notes (the cap level left for the mobs, quests whose XP is not
-- known yet).
local function one(v) return math.floor(v * 10 + 0.5) / 10 end

-- A stop level as the game's XP bar shows it (U85): level and percent, "level 26, 60% into it", not 26.6. short:
-- the level track's tick, "stop 26 (60%)".
function R.StopAt(v, short)
  v = math.max(v, 1)
  local lvl = math.floor(v)
  local pct = math.floor((v - lvl) * 100 + 0.5)
  if pct >= 100 then lvl, pct = lvl + 1, 0 end
  if short then return pct > 0 and L.ROOM_TICK:format(lvl, pct) or L.ROOM_TICK_0:format(lvl) end
  return pct > 0 and L.ROOM_AT:format(lvl, pct) or L.ROOM_AT_0:format(lvl)
end

function R.Lines(r)
  local cap = r.tol > 0 and L.ROOM_CAP_TOL:format(r.cap, r.tol) or L.ROOM_CAP:format(r.cap)
  local main = L.ROOM_LINE:format(one(r.levels), one(r.to), cap)
  local stop = r.stop and L.ROOM_STOP:format(R.StopAt(r.stop)) or nil
  local notes = { L.ROOM_MOBS:format(r.cap + r.tol) }
  if r.unknown > 0 then notes[#notes + 1] = r.unknown == 1 and L.ROOM_UNKNOWN_1 or L.ROOM_UNKNOWN_N:format(r.unknown) end
  return main, stop, table.concat(notes, "  ")
end
R.One = one

-- The room as the answer a player wants (U145): "You have room: stop questing at level 18." in green; red from half a
-- level before the stop point ("Stop questing at level 26, 60% into it ..."), and "Stop questing now ..." once there.
-- Returns the text, its colour and the figures for its tooltip.
function R.Answer(r)
  r.stopAt = r.stopAt or r.stop or r.limit
  local main, _, notes = R.Lines(r)
  local tip = main .. "\n" .. L.ROOM_EXACT:format(one(r.stopAt)) .. "\n" .. notes
  if r.now >= r.stopAt then return L.ROOM_NOW, "B0321E", tip end
  if r.stop then return L.ROOM_STOP:format(R.StopAt(r.stopAt)), "B0321E", tip end
  return L.ROOM_HAVE:format(R.StopAt(r.stopAt)), "3E7A3A", tip
end

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
    ns:Toast("room", L.TOAST_ROOM_SOON_TITLE, L.TOAST_ROOM_SOON:format(R.StopAt(stop)), "overview")
  end
end

-- The two warnings follow the XP bar.
ns:RegisterEvent("PLAYER_XP_UPDATE", function()
  if not R.checking then
    R.checking = true
    C_Timer.After(2, function() R.checking = nil; R:Check() end)
  end
end)
