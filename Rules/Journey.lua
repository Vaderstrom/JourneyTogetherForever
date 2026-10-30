-- Chapter progress (SPEC §2, the mockup's cleared / chDone / cur / bannerFor / groups / nextSteps).
--   current chapter: the first chapter that is not complete
--   a chapter with mandatory or bridge dungeons is complete when all of them are cleared (clear requirement);
--   a chapter without them when every counted Hero has reached the cap. Counted Heroes: everyone not away.
--   dungeons open when every counted Hero is at least floor − floor allowance.
-- No frames here: the pages read these functions.
local _, ns = ...
local L = ns.L
local J = {}
ns.Journey = J

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX" }
function J.Roman(n) return ROMAN[n] or tostring(n) end

local function level(f, name) return ns.Hero:Level(f, name) end

-- Why a Hero is away: "self", "forced" (by the leader), "auto" (not seen for the rule's number of days), or nil.
function J:Away(f, name)
  local m = f.members[name]
  if not m then return nil end
  if m.away then return m.away end
  local r = f.rules
  if not r.awayNever and name ~= ns.Me() and time() - ns.Hero:LastSeen(f, name) > (r.awayDays or 14) * 86400 then return "auto" end
  return nil
end

-- Heroes not away, highest level first.
function J:Counted(f)
  local list = {}
  for name in pairs(f.members) do if not self:Away(f, name) then list[#list + 1] = name end end
  table.sort(list, function(a, b)
    local la, lb = level(f, a), level(f, b)
    if la ~= lb then return la > lb end
    return a < b
  end)
  return list
end

-- The Heroes who set the pace: counted, and not catching up (27 Oct 2026). Chapter goals, clears and milestones wait
-- for them only; a newcomer catching up counts from the time they reach the floor (J:CatchingUp). Votes, standings
-- and the counts still list everyone counted.
function J:Pacing(f)
  local list = {}
  for _, name in ipairs(self:Counted(f)) do if not self:CatchingUp(f, name) then list[#list + 1] = name end end
  return list
end

-- The dungeons placed in chapter n: { key, role, d (the DUNGEONS entry) }, by best level.
function J:InChapter(f, n)
  local list = {}
  for key, p in pairs(f.journey.place) do
    local d = ns.Dungeon(key)
    if d and p.ch == n then list[#list + 1] = { key = key, role = p.role, d = d } end
  end
  table.sort(list, function(a, b)
    if a.d[3] ~= b.d[3] then return a.d[3] < b.d[3] end
    return a.key < b.key
  end)
  return list
end

-- The bridge dungeons of chapter n + 1: they may be run in chapter n already (SPEC §1), so chapter n lists them too
-- (asked for after the in-game run of 27 Oct 2026). They still count for their own chapter; x.early is that chapter.
function J:EarlyBridges(f, n)
  local list = {}
  for _, x in ipairs(self:InChapter(f, n + 1)) do
    if x.role == "b" then x.early = n + 1; list[#list + 1] = x end
  end
  return list
end

-- A chapter's dungeons as its pages list them: its own, then the next chapter's bridges.
function J:ChapterList(f, n)
  local list = self:InChapter(f, n)
  for _, x in ipairs(self:EarlyBridges(f, n)) do list[#list + 1] = x end
  return list
end

-- Each role's colour: { on parchment and cards, on dark pictures }. Mandatory gold, bridge blue, optional green.
J.ROLE_COLOR = { m = { "A8761E", "F0C860" }, b = { "2F6FAE", "8CC0F0" }, o = { "4F7F3F", "A8D090" } }

-- Mandatory and bridge dungeons (optional ones never block progress).
function J:Required(f, n)
  local list = {}
  for _, x in ipairs(self:InChapter(f, n)) do if x.role ~= "o" then list[#list + 1] = x end end
  return list
end

-- Who has cleared a dungeon: f.runs[key] = { name = time } (Fellowship/Clears.lua).
function J:ClearedBy(f, key)
  local who = f.runs and f.runs[key]
  return type(who) == "table" and who or {}
end

-- Cleared by the clear requirement: one run, a number of Heroes, or every counted Hero.
function J:Cleared(f, key)
  local who = self:ClearedBy(f, key)
  if not next(who) then return false end
  local r = f.rules
  if r.clearMode == "one" then return true end
  local counted = self:Pacing(f)
  local have = 0
  for _, name in ipairs(counted) do if who[name] then have = have + 1 end end
  if r.clearMode == "n" then return have >= math.min(r.clearN, #counted) end
  return have >= #counted
end

-- The furthest chapter the fellowship has reached. Every chapter before it stays complete, also when a Hero joins
-- or comes back from away (decided after the in-game self-test): newcomers catch up on their own. Only the leader's
-- Undo clear takes the fellowship back (J:Reopen).
function J:Reached(f) return math.max(1, tonumber(f.reached) or 1) end

-- The earlier chapter a dungeon's clear holds complete: it is needed in a chapter before the current one. nil when
-- it is optional or in the current chapter or later.
function J:ReopensChapter(f, key)
  local p = f.journey.place[key]
  if not p or p.role == "o" then return nil end
  if p.ch < self:CurrentIndex(f) then return p.ch end
  return nil
end

-- Back to chapter n: from n on, chapters count again by their own clears and levels. reopenV: the version of this
-- change (the op gets f.v + 1), so a copy taken later lowers f.reached only for a newer reopen (Sync, SNAP).
function J:Reopen(f, n)
  if n < self:Reached(f) then f.reached = n end
  f.reopenV = f.v + 1
end

-- The chapter's own goal: its required dungeons cleared, or without them every counted Hero at the cap.
function J:GoalDone(f, n)
  local ch = f.journey.chapters[n]
  if not ch then return true end
  local req = self:Required(f, n)
  if #req > 0 then
    for _, x in ipairs(req) do if not self:Cleared(f, x.key) then return false end end
    return true
  end
  local counted = self:Pacing(f)
  if #counted == 0 then return false end
  for _, name in ipairs(counted) do if level(f, name) < ch.cap then return false end end
  return true
end

-- Complete: reached past it, or its goal and its Required milestones (Rules/Milestones.lua) are done.
function J:Done(f, n)
  if n < self:Reached(f) then return true end
  if not f.journey.chapters[n] then return true end
  return self:GoalDone(f, n) and #ns.Milestones:OpenRequired(f, n) == 0
end

-- Number of the current chapter (#chapters + 1 when the journey is complete). It only moves forward: reaching a
-- chapter is remembered in f.reached.
function J:CurrentIndex(f)
  local cur = #f.journey.chapters + 1
  for n = 1, #f.journey.chapters do if not self:Done(f, n) then cur = n break end end
  if cur > self:Reached(f) then f.reached = cur end
  return cur
end

-- { n, of, floor, cap, name } of the current chapter, or nil when the journey is complete.
function J:Current(f)
  local n = self:CurrentIndex(f)
  local ch = f.journey.chapters[n]
  if not ch then return nil end
  return { n = n, of = #f.journey.chapters, floor = ch.floor, cap = ch.cap, name = ch.name }
end

function J:FloorLevel(f, ch) return ch.floor - f.rules.floorTol end

-- Counted Heroes below the floor of chapter n who hold it. Newcomers catching up do not (27 Oct 2026): someone who
-- joins, or takes a place, below the floor counts from the time they reach it (J:CatchingUp).
function J:Below(f, n)
  local ch, list = f.journey.chapters[n], {}
  if not ch then return list end
  for _, name in ipairs(self:Counted(f)) do
    if level(f, name) < self:FloorLevel(f, ch) and not self:CatchingUp(f, name) then list[#list + 1] = name end
  end
  return list
end

-- A newcomer still below the floor of the current chapter (members[name].catching, set when they joined below it).
function J:CatchingUp(f, name)
  local m = f.members[name]
  return m ~= nil and m.catching == true
end

-- Marks a newcomer catching up when they arrive below the current chapter's floor while the fellowship is past its
-- first chapter (after the Prologue) (Fellowship:Apply, join and swap). Friends joining at the start hold the first
-- chapter as usual.
function J:MarkNewcomer(f, name, lvl)
  local ch = self:Current(f)
  local first = (f.journey.chapters[1] and f.journey.chapters[1].art == "prologue") and 2 or 1
  if ch and ch.n > first and f.members[name] and (tonumber(lvl) or 0) < self:FloorLevel(f, ch) then f.members[name].catching = true end
end

-- Their level reached the current floor: from now on they count like everyone (Hero:Store). Returns true when it changed.
function J:CaughtUp(f, name)
  local m = f.members[name]
  local ch = m and m.catching and self:Current(f)
  if ch and level(f, name) >= self:FloorLevel(f, ch) then m.catching = nil return true end
  if m and m.catching and not ch then m.catching = nil return true end
  return false
end

-- Dungeons of the current chapter are open when nobody counted is below the floor.
function J:Unlocked(f) return #self:Below(f, self:CurrentIndex(f)) == 0 end

-- How far Heroes can read ahead: every chapter (rule, or the leader), else up to the current one.
function J:MaxView(f, me)
  local count = #f.journey.chapters
  if f.rules.showFuture or f.leader == me then return count end
  return math.min(self:CurrentIndex(f), count)
end

-- A dungeon of the journey is open in an earlier chapter, in the current one once it is unlocked, and as a
-- bridge one chapter early. A raid is open once the Endgame is (Fellowship/Endgame.lua).
function J:Open(f, key)
  local p = f.journey.place[key]
  if not p then return ns.Raid(key) ~= nil and ns.Endgame:Open(f) end
  local cur = self:CurrentIndex(f)
  local unlocked = self:Unlocked(f)
  return p.ch < cur or (p.ch == cur and unlocked) or (p.ch == cur + 1 and p.role == "b" and unlocked)
end

-- State of a dungeon in chapter n: "cleared", "open" or "locked".
function J:DungeonState(f, _, x)
  if self:Cleared(f, x.key) then return "cleared" end
  return self:Open(f, x.key) and "open" or "locked"
end

-- With levels (the "Waiting for ..." lines) you are "you": the You card said "you're the last one" next to
-- "Waiting for Edstromar (2)" (seen in the tour).
local function names(f, list, withLevel)
  local out = {}
  for _, name in ipairs(list) do
    local mine = withLevel and name == ns.Me()
    local text = (mine and L.NAME_YOU or ns.Short(name)) .. (withLevel and (" (" .. level(f, name) .. ")") or "")
    -- You first ("Waiting for you (2), Brannic (2), ..."), not somewhere in the middle.
    if mine then table.insert(out, 1, text) else out[#out + 1] = text end
  end
  return table.concat(out, ", ")
end
J.Names = names

-- The status banner of chapter n: { icon, title, text, color, step } (SPEC §2).
function J:Banner(f, n)
  local ch = f.journey.chapters[n]
  if not ch then return { icon = "done", title = L.BN_JOURNEY_DONE, text = L.BN_JOURNEY_DONE_TEXT, color = "3E7A3A", step = "", stage = "end" } end
  local cur = self:CurrentIndex(f)
  local req = self:Required(f, n)
  if n > cur then
    -- The chapter just before it, and where the fellowship is when that is further back (every later chapter said
    -- "opens when Chapter I is complete"; seen in game).
    local text = L.BN_NOT_STARTED_TEXT:format(J.Roman(n - 1))
    if n - 1 > cur then text = text .. L.BN_NOT_STARTED_NOW:format(J.Roman(cur)) end
    return { icon = "locked", title = L.BN_NOT_STARTED, text = text, color = "7A6A55", step = "", stage = "later" }
  end
  if n < cur then
    return { icon = "done", title = L.BN_COMPLETE, text = #req > 0 and L.BN_COMPLETE_DUNGEONS or L.BN_COMPLETE_LEVELS:format(ch.cap),
      color = "3E7A3A", step = #req > 0 and L.STEP_3_DONE or L.STEP_2_DONE, stage = "done" }
  end
  local below = self:Below(f, n)
  if #below > 0 then
    return { icon = "waiting", title = L.BN_WAITING, text = L.BN_WAITING_TEXT:format(self:FloorLevel(f, ch), names(f, below, true)),
      color = "B8742A", step = L.STEP_1_FLOOR, stage = "floor", below = below }
  end
  -- Dungeons (or levels) done, Required milestones left.
  local open = ns.Milestones:OpenRequired(f, n)
  if #open > 0 and self:GoalDone(f, n) then
    local text = #open == 1 and L.BN_MILESTONES_TEXT_1:format(open[1].name) or L.BN_MILESTONES_TEXT_N:format(#open, open[1].name)
    return { icon = "open", title = L.BN_MILESTONES, text = text, color = "2E5E9A", step = L.STEP_MILESTONES, stage = "milestones" }
  end
  if #req == 0 then
    local counted, there = self:Pacing(f), 0
    for _, name in ipairs(counted) do if level(f, name) >= ch.cap then there = there + 1 end end
    return { icon = "level", title = L.BN_LEVEL, text = L.BN_LEVEL_TEXT:format(ch.cap, there, #counted), color = "2E5E9A", step = L.STEP_2_LEVEL, stage = "level" }
  end
  local left = {}
  for _, x in ipairs(req) do if not self:Cleared(f, x.key) then left[#left + 1] = x end end
  local text = L.BN_OPEN_TEXT:format(#req - #left, #req) .. (#left > 0 and L.BN_OPEN_NEXT:format(left[1].d[2]) or "")
  return { icon = "open", title = L.BN_OPEN, text = text, color = "2E7A3E", step = L.STEP_2_RUN, stage = "run" }
end

-- The stages of chapter n, for the Chapter page's track (28 Oct 2026): everyone at the floor, then the dungeons (or
-- levelling to the cap when it has none), the Required milestones when it has any, then complete. Each node:
-- { key, label, state = "done" | "current" | "todo" }. Also returns the banner (its colour marks the current node).
function J:Stages(f, n)
  local ch = f.journey.chapters[n]
  if not ch then return {}, self:Banner(f, n) end
  local b = self:Banner(f, n)
  local hasDungeons = #self:Required(f, n) > 0
  local nodes = { { key = "floor", label = L.STAGE_FLOOR:format(self:FloorLevel(f, ch)) },
    { key = hasDungeons and "run" or "level", label = hasDungeons and L.STAGE_RUN or L.STAGE_LEVEL:format(ch.cap) } }
  for _, m in ipairs(ns.Milestones:List(f, n)) do
    if m.req then nodes[#nodes + 1] = { key = "milestones", label = L.STAGE_MILESTONES }; break end
  end
  nodes[#nodes + 1] = { key = "complete", label = L.STAGE_COMPLETE }
  local at = 0 -- the current node; 0 = not started, past the last = all done
  if b.stage == "done" then at = #nodes + 1
  elseif b.stage ~= "later" then
    for i, x in ipairs(nodes) do if x.key == b.stage then at = i end end
  end
  for i, x in ipairs(nodes) do x.state = i < at and "done" or (i == at and "current" or "todo") end
  return nodes, b
end

-- The first level that is no longer "ready" in a chapter: the cap; in a one-level chapter (floor = cap, such as
-- 60-60 for raids) being at that level is ready, only above it counts as over.
local function readyBelow(ch) return ch.floor >= ch.cap and ch.cap + 1 or ch.cap end

-- Overview counts for chapter n: below the floor, ready, at the cap (with its allowance), over the cap, away.
-- (Over the cap is its own count since 27 Oct 2026: it was folded into "at or over the cap" and hard to spot.)
function J:Counts(f, n)
  local ch = f.journey.chapters[n]
  if not ch then return {} end
  local fl, top, over = self:FloorLevel(f, ch), readyBelow(ch), ch.cap + f.rules.capTol
  local below, ready, cap, above, away = 0, 0, 0, 0, 0
  for name in pairs(f.members) do
    if self:Away(f, name) then away = away + 1
    else
      local lv = level(f, name)
      if lv < fl then below = below + 1 elseif lv < top then ready = ready + 1 elseif lv <= over then cap = cap + 1 else above = above + 1 end
    end
  end
  return { { L.CNT_BELOW, below, "B0321E" }, { L.CNT_READY, ready, "2E7A3E" }, { L.CNT_CAP, cap, "B8742A" },
    { L.CNT_OVER, above, "C0392B" }, { L.CNT_AWAY, away, "ink2" } }
end

-- Where the Heroes stand in chapter n (Chapter page): groups { label, range, color, rows = { { name, note } } }.
function J:Groups(f, n)
  local ch = f.journey.chapters[n]
  if not ch then return {} end
  local fl, cap, tol, top = self:FloorLevel(f, ch), ch.cap, f.rules.capTol, readyBelow(ch)
  -- Levels to a target with the XP into this level, as the You card says it ("2.6 levels"; the whole "3 levels"
  -- here disagreed with it; seen in the check, 29 Oct 2026).
  local function far(name, target)
    local h = ns.Hero:Get(f, name) or {}
    local k = ns.Pace.LevelsTo(level(f, name), h.xp, h.xpMax, target)
    if k == math.floor(k) then return (k == 1 and L.LEVELS_1 or L.LEVELS_N):format(k) end
    return L.LEVELS_DEC:format(k)
  end
  local g = {
    { label = L.GRP_BELOW, range = L.GRP_BELOW_RANGE:format(fl), color = "B0321E", rows = {} },
    { label = L.GRP_READY, range = fl >= top - 1 and L.GRP_READY_ONE:format(top - 1) or L.GRP_READY_RANGE:format(fl, top - 1),
      color = "2E7A3E", rows = {} },
    { label = L.GRP_CAP, range = cap + tol > top and L.GRP_READY_RANGE:format(top, cap + tol) or L.GRP_READY_ONE:format(top),
      color = "B8742A", rows = {} },
    { label = L.GRP_OVER, range = L.GRP_CAP_RANGE:format(cap + tol + 1), color = "C0392B", rows = {} },
    { label = L.GRP_AWAY, range = L.GRP_AWAY_RANGE, color = "ink2", rows = {} },
  }
  for _, name in ipairs(self:Counted(f)) do
    local l = level(f, name)
    if l < fl then
      table.insert(g[1].rows, { name = name, note = (self:CatchingUp(f, name) and L.NOTE_CATCHING or L.NOTE_TO_FLOOR):format(far(name, fl)) })
    elseif l < top then table.insert(g[2].rows, { name = name, note = l < cap and L.NOTE_TO_CAP:format(far(name, cap)) or L.NOTE_AT_CAP })
    elseif l > cap + tol then table.insert(g[4].rows, { name = name, note = L.NOTE_OVER_BY:format(l - cap - tol) })
    else table.insert(g[3].rows, { name = name, note = l > cap and L.NOTE_OVER_ALLOWED:format(l - cap) or L.NOTE_AT_CAP })
    end
  end
  local away = {}
  for name in pairs(f.members) do if self:Away(f, name) then away[#away + 1] = name end end
  table.sort(away)
  for _, name in ipairs(away) do
    local why = self:Away(f, name)
    table.insert(g[5].rows, { name = name, note = why == "forced" and L.NOTE_AWAY_FORCED
      or (why == "auto" and L.NOTE_AWAY_AUTO:format(math.floor((time() - ns.Hero:LastSeen(f, name)) / 86400)) or L.NOTE_AWAY) })
  end
  return g
end

-- Heroes over the cap (+ allowance) in the current chapter.
function J:OverCap(f)
  local ch = self:Current(f)
  local list = {}
  if not ch then return list end
  for _, name in ipairs(self:Counted(f)) do if level(f, name) > ch.cap + f.rules.capTol then list[#list + 1] = name end end
  return list
end

-- "What's next" on the Overview (quest lines arrive with M6): { icon, text }.
function J:NextSteps(f)
  local steps = {}
  local ch = self:Current(f)
  if not ch then return { { icon = "done", text = L.NEXT_JOURNEY_DONE } } end
  local n = ch.n
  local counted = self:Pacing(f)
  local below = self:Below(f, n)
  if #below > 0 then steps[#steps + 1] = { kind = "waiting", icon = "waiting", text = L.NEXT_WAITING:format(names(f, below, true), self:FloorLevel(f, ch)) } end
  local unlocked = #below == 0
  if unlocked and #self:Required(f, n) == 0 then
    local there = 0
    for _, name in ipairs(counted) do if level(f, name) >= ch.cap then there = there + 1 end end
    steps[#steps + 1] = { kind = "level", icon = "level", text = #counted == 1 and L.NEXT_LEVEL_ONE:format(ch.cap, there)
      or L.NEXT_LEVEL:format(ch.cap, there, #counted) }
  end
  if unlocked then
    for _, x in ipairs(self:Required(f, n)) do
      if not self:Cleared(f, x.key) then
        local count = 0
        for _ in pairs(self:ClearedBy(f, x.key)) do count = count + 1 end
        steps[#steps + 1] = { kind = "dungeon", icon = "open", text = #counted == 1 and L.NEXT_DUNGEON_ONE:format(x.d[2], count)
          or L.NEXT_DUNGEON:format(x.d[2], count, #counted) }
      end
    end
  end
  -- Required milestones of this chapter not done yet.
  for _, m in ipairs(ns.Milestones:OpenRequired(f, n)) do
    steps[#steps + 1] = { kind = "milestone", icon = "open", text = L.NEXT_MILESTONE:format(m.name, ns.Milestones:ProgressText(f, m)) }
  end
  -- At the cap, not over it: those over it have their own red line ("X is at the cap" stood next to "X is over the
  -- cap"; seen in the check, 29 Oct 2026).
  local atCap = {}
  for _, name in ipairs(self:Counted(f)) do
    local lv = level(f, name)
    if lv >= ch.cap and lv <= ch.cap + f.rules.capTol then atCap[#atCap + 1] = name end
  end
  if #atCap > 0 then steps[#steps + 1] = { kind = "cap", icon = "cap", text = (#atCap == 1 and L.NEXT_AT_CAP_1 or L.NEXT_AT_CAP_N):format(names(f, atCap)) } end
  -- Quests and chains in my log that other Heroes have too (Fellowship/Quests.lua).
  if ns.Quests then
    local singles, chains = ns.Quests:SharedCounts(f)
    if singles > 0 then steps[#steps + 1] = { kind = "quest", icon = "quest", text = (singles == 1 and L.NEXT_QUESTS_1 or L.NEXT_QUESTS_N):format(singles) } end
    if chains > 0 then steps[#steps + 1] = { kind = "chain", icon = "chain", text = (chains == 1 and L.NEXT_CHAINS_1 or L.NEXT_CHAINS_N):format(chains) } end
  end
  if #steps == 0 then steps[1] = { kind = "done", icon = "done", text = L.NEXT_ALL_CLEARED } end
  return steps
end

-- "Floor 25 (−1 allowed)  ·  cap 29 (+1 allowed)"
function J:LevelsLine(f, ch)
  local r = f.rules
  return L.LINE_FLOOR:format(ch.floor) .. (r.floorTol > 0 and L.LINE_FLOOR_TOL:format(r.floorTol) or "")
    .. L.LINE_CAP:format(ch.cap) .. (r.capTol > 0 and L.LINE_CAP_TOL:format(r.capTol) or "")
end

---------------------------------------------------------------------------
-- Journey data: checking a journey that another Hero sends, and the export string
---------------------------------------------------------------------------
J.MAX_CHAPTERS = 30

-- A clean copy of a journey, or nil when it is not valid.
function J.Clean(journey)
  if type(journey) ~= "table" or type(journey.chapters) ~= "table" then return nil end
  local out = { chapters = {}, place = {} }
  for i, c in ipairs(journey.chapters) do
    if i > J.MAX_CHAPTERS or type(c) ~= "table" then return nil end
    local floor, cap = tonumber(c.floor), tonumber(c.cap)
    local name = type(c.name) == "string" and strtrim(c.name) or ""
    -- floor = cap is allowed: a one-level chapter, such as 60-60 for raids.
    if not floor or not cap or floor < 1 or cap > 60 or floor > cap or name == "" or #name > 48 then return nil end
    -- art: the chapter's picture (a preset chapter's number, or "prologue"); none: by its place, as before.
    local art = c.art == "prologue" and "prologue" or (tonumber(c.art) and math.floor(c.art) >= 1 and math.floor(c.art) <= 30 and math.floor(c.art)) or nil
    out.chapters[i] = { name = name, floor = math.floor(floor), cap = math.floor(cap), color = type(c.color) == "string" and c.color:match("^%x%x%x%x%x%x$") and c.color or ns.PALETTE[(i - 1) % #ns.PALETTE + 1],
      milestones = ns.Milestones.Clean(c.milestones), art = art }
  end
  if #out.chapters == 0 then return nil end
  for key, p in pairs(type(journey.place) == "table" and journey.place or {}) do
    -- Old keys (Blackrock Depths' two parts) become placements of one dungeon, each with its half of the bosses.
    local old = ns.KEY_ALIAS[key]
    if old then key = old end
    if ns.Dungeon(key) and type(p) == "table" and (p.role == "m" or p.role == "b" or p.role == "o")
      and tonumber(p.ch) and p.ch >= 1 and p.ch <= #out.chapters then
      out.place[key] = { ch = math.floor(p.ch), role = p.role }
      -- Needed bosses chosen in Journey Admin (boss tokens, see Fellowship/Clears.lua); nil = every boss.
      if type(p.bosses) == "table" then
        local bosses = {}
        for _, tok in ipairs(p.bosses) do
          if type(tok) == "string" and tok:match("^[en].") and #tok <= 80 and #bosses < 40 then bosses[#bosses + 1] = tok end
        end
        out.place[key].bosses = bosses
      elseif old then
        out.place[key].bosses = J.SplitTokens(ns.BaseKey(key), tonumber(key:match("#(%d+)$")) or 1)
      end
    end
  end
  return out
end

-- The boss tokens of part i of a dungeon's split (Data/Dungeons.lua, DUNGEON_SPLITS): the game's encounter when it
-- knows the boss, else its name (learned on the kill).
function J.SplitTokens(base, i)
  local part = ns.DUNGEON_SPLITS[base] and ns.DUNGEON_SPLITS[base][i]
  if not part then return nil end
  local _, all = ns.Clears:DataBosses(base)
  local out = {}
  for _, name in ipairs(part) do
    local tok = "n" .. name
    for _, b in ipairs(all or {}) do if b.name == name then tok = b.tok end end
    out[#out + 1] = tok
  end
  return out
end

-- Kills, clears, undone clears, history and Gatherings saved under old keys move to the new ones.
function J.MigrateKeys(f)
  for old, new in pairs(ns.KEY_ALIAS) do
    for _, t in ipairs({ f.kills, f.runs, f.undone }) do
      if type(t) == "table" and t[old] ~= nil then
        if t[new] == nil then t[new] = t[old] end
        t[old] = nil
      end
    end
    for _, e in ipairs(type(f.history) == "table" and f.history or {}) do if e.key == old then e.key = new end end
    for _, g in pairs(type(f.gatherings) == "table" and f.gatherings or {}) do
      if type(g) == "table" and g.key == old then g.key = ns.BaseKey(old) end
    end
  end
end

J.EXPORT_PREFIX = "JTF1:"

function J.Export(journey) return J.EXPORT_PREFIX .. ns.Serialize.Encode(J.Clean(journey) or journey) end

-- The journey in an export string, or nil.
function J.Import(text)
  text = strtrim(text or "")
  if text:sub(1, #J.EXPORT_PREFIX) ~= J.EXPORT_PREFIX then return nil end
  local data, ok = ns.Serialize.Decode(text:sub(#J.EXPORT_PREFIX + 1))
  return ok and J.Clean(data) or nil
end

-- Problems with chapter n of a (draft) journey, for Journey Admin.
function J.Issues(journey, n)
  local out = {}
  local ch, prev = journey.chapters[n], journey.chapters[n - 1]
  if ch and ch.floor > ch.cap then out[#out + 1] = L.ISSUE_FLOOR_CAP end
  if ch and prev and prev.cap ~= ch.floor then out[#out + 1] = L.ISSUE_PREV_CAP:format(prev.cap) end
  return out
end
