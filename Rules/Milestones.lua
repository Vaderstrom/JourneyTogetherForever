-- Milestones in a chapter (SPEC §2, M17): goals besides the dungeons, added per chapter in Journey Admin.
--   quest   every counted Hero has handed in a quest (value = quest ID; the game's own record, shared with the quest
--           log like the attunement lists)
--   level   every counted Hero has reached a level (value = level)
--   attune  every counted Hero has an attunement or key from our list (value = its key, Data/QuestLists.lua)
--   tick    the leader (or officers who may change clears) ticks it off by hand (a free text)
-- Each is Required (the chapter is not complete until it is done) or Optional (a goal shown on the Chapter page).
-- Stored with the chapter: f.journey.chapters[n].milestones = { { id, kind, value, name, req } }; ticks in
-- f.ticks[id] = { by, t } (an op, "tick").
local _, ns = ...
local L = ns.L
local M = { KINDS = { quest = true, level = true, attune = true, tick = true }, MAX = 10 }
ns.Milestones = M

-- Is there an attunement or key with this key (either side)?
local function attuneKnown(key)
  for _, a in ipairs(ns.ATTUNEMENTS) do if a.key == key then return true end end
  return false
end

-- A clean list of milestones (invalid ones are dropped), or nil when none is left.
function M.Clean(list)
  if type(list) ~= "table" then return nil end
  local out, seen = {}, {}
  for _, m in ipairs(list) do
    if #out >= M.MAX then break end
    if type(m) == "table" and M.KINDS[m.kind] and type(m.id) == "string" and m.id:match("^%w+$") and #m.id <= 24
      and not seen[m.id] then
      local name = type(m.name) == "string" and strtrim(m.name) or ""
      local v, ok = m.value, name ~= "" and #name <= 60
      if m.kind == "quest" then
        v = tonumber(v); ok = ok and v ~= nil and v > 0 and v == math.floor(v)
      elseif m.kind == "level" then
        v = tonumber(v); ok = ok and v ~= nil and v >= 1 and v <= ns.HighestLevel() and v == math.floor(v)
      elseif m.kind == "attune" then
        ok = ok and type(v) == "string" and attuneKnown(v)
      else
        v = nil
      end
      if ok then
        seen[m.id] = true
        out[#out + 1] = { id = m.id, kind = m.kind, value = v, name = name, req = m.req == true }
      end
    end
  end
  return #out > 0 and out or nil
end

-- A new milestone's ID (unique enough within a journey).
function M.NewID() return ("m%d%03d"):format(time(), math.random(0, 999)) end

-- The default name for a milestone of kind with value (Journey Admin fills it in; the leader can change it).
function M.DefaultName(kind, value)
  if kind == "level" then return L.MS_NAME_LEVEL:format(value) end
  if kind == "quest" then
    local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(value)
    return L.MS_NAME_QUEST:format(title or ("#" .. value))
  end
  if kind == "attune" then
    for _, a in ipairs(ns.ATTUNEMENTS) do if a.key == value then return L.MS_NAME_ATTUNE:format(a.name) end end
  end
  return ""
end

function M:List(f, n)
  local ch = f.journey.chapters[n]
  return ch and ch.milestones or {}
end

-- The milestone with this ID anywhere in the journey, and its chapter.
function M:Find(f, id)
  for n, ch in ipairs(f.journey.chapters) do
    for _, m in ipairs(ch.milestones or {}) do if m.id == id then return m, n end end
  end
  return nil
end

-- Has this Hero done it? (Not for ticks: those are for the whole fellowship.)
function M:HeroDone(f, m, name)
  if m.kind == "level" then return ns.Hero:Level(f, name) >= m.value end
  if m.kind == "quest" then
    local h = ns.Hero:Get(f, name)
    return h ~= nil and h.questsDone ~= nil and h.questsDone[m.value] == true
  end
  if m.kind == "attune" then
    for _, a in ipairs(ns.QuestLists:Attunements(f)) do
      if a.key == m.value then return ns.QuestLists:Progress(f, a, name).done end
    end
  end
  return false
end

-- { done, have, of } (every counted Hero), or for a tick { done, by }.
function M:Progress(f, m)
  if m.kind == "tick" then
    local t = f.ticks and f.ticks[m.id]
    return { done = t ~= nil, by = t and t.by }
  end
  local counted, have = ns.Journey:Pacing(f), 0
  for _, name in ipairs(counted) do if self:HeroDone(f, m, name) then have = have + 1 end end
  return { done = #counted > 0 and have >= #counted, have = have, of = #counted }
end

-- The Required milestones of chapter n that are not done yet.
function M:OpenRequired(f, n)
  local out = {}
  for _, m in ipairs(self:List(f, n)) do if m.req and not self:Progress(f, m).done then out[#out + 1] = m end end
  return out
end

-- "3 of 4 Heroes" or "Ticked by Lea" / "Not ticked yet".
function M:ProgressText(f, m)
  local p = self:Progress(f, m)
  if m.kind == "tick" then return p.done and L.MS_TICKED_BY:format(ns.Short(p.by or "?")) or L.MS_NOT_TICKED end
  return L.MS_HEROES:format(p.have, p.of)
end

-- Quest IDs of the journey's quest milestones (each Hero shares whether the game has them as done).
function M:QuestIDs(f)
  local out = {}
  for _, ch in ipairs(f and f.journey.chapters or {}) do
    for _, m in ipairs(ch.milestones or {}) do if m.kind == "quest" then out[#out + 1] = m.value end end
  end
  return out
end
