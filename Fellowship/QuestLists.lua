-- Attunements, keys and dungeon quests (SPEC §6) from our own lists (Data/QuestLists.lua). Each Hero's addon checks
-- which of these quests the game has flagged as done and which keys they carry, and shares it with the quest log
-- (QUESTS: d = done quest IDs, k = key item IDs; Fellowship/Quests.lua). So the fellowship sees, from the first day,
-- who still needs a step or a dungeon's quests; nobody waits at the door without the key.
local _, ns = ...
local L = ns.L
local F, Hr = ns.Fellowship, ns.Hero
local QL = {}
ns.QuestLists = QL

local SIDE = { Alliance = "A", Horde = "H" }

-- The side ("A"/"H") of a fellowship, or nil.
local function side(f) return f and SIDE[f.faction or ""] end
local function forSide(x, s) return x.side == nil or s == nil or x.side == s end

-- Every quest ID in the lists (for MyDone), once.
function QL:AllIDs()
  if self.all then return self.all end
  local list, seen = {}, {}
  local function add(id) if not seen[id] then seen[id] = true; list[#list + 1] = id end end
  for _, a in ipairs(ns.ATTUNEMENTS) do
    for _, st in ipairs(a.steps) do for _, id in ipairs(st[1]) do add(id) end end
  end
  for _, quests in pairs(ns.DUNGEON_QUESTS) do for _, q in ipairs(quests) do add(q[1]) end end
  self.all = list
  return list
end

-- The key and attunement items I carry (bags and bank).
function QL:MyKeys()
  local out, count = {}, C_Item and C_Item.GetItemCount
  if not count then return out end
  for _, a in ipairs(ns.ATTUNEMENTS) do
    if a.item and (count(a.item, true) or 0) > 0 then out[#out + 1] = a.item end
  end
  table.sort(out)
  return out
end

---------------------------------------------------------------------------
-- Attunements
---------------------------------------------------------------------------
-- The attunements for this fellowship's side. With viewer: only the ones that Hero can work on, that is from the
-- attunement's start level, or already started or done (the far-off ones are left out until they matter).
function QL:Attunements(f, viewer)
  local s, list = side(f), {}
  for _, a in ipairs(ns.ATTUNEMENTS) do
    if forSide(a, s) and (not viewer or self:CanStart(f, a, viewer)) then list[#list + 1] = a end
  end
  return list
end

-- QL.viewLevel: /jtf tour and /jtf selftest look at the attunements as a level 60 would (their characters are low).
local function levelOf(f, name)
  if name == ns.Me() then return QL.viewLevel or UnitLevel("player") or 0 end
  local h = Hr:Get(f, name)
  return h and tonumber(h.level) or 0
end

function QL:CanStart(f, a, name)
  if levelOf(f, name) >= (a.level or 1) then return true end
  local p = self:Progress(f, a, name)
  return p.done or p.n > 0 or p.at ~= nil
end

-- The next attunement or key a Hero can reach: the lowest start level above theirs (the list is sorted by level).
function QL:Next(f, name)
  local s, lvl = side(f), levelOf(f, name)
  for _, a in ipairs(ns.ATTUNEMENTS) do
    if forSide(a, s) and (a.level or 0) > lvl then return a end
  end
end

-- Attunements (for side s) whose start level lies in (from, to]: they became available on a level up.
function QL:NewlyAvailable(s, from, to)
  local out = {}
  for _, a in ipairs(ns.ATTUNEMENTS) do
    if forSide(a, s) and a.level and a.level > from and a.level <= to then out[#out + 1] = a end
  end
  return out
end

-- A Hero's progress: { done (attuned or has the key), n (steps done), of, at (the step in their log, or nil),
-- steps = { true/false } }
function QL:Progress(f, a, name)
  local h = Hr:Get(f, name) or {}
  local doneSet, log, keys = h.questsDone or {}, h.quests or {}, h.keys or {}
  local p = { n = 0, of = #a.steps, steps = {} }
  for i, st in ipairs(a.steps) do
    local ok = false
    for _, id in ipairs(st[1]) do
      if doneSet[id] then ok = true end
      if log[id] and not p.at then p.at = i end
    end
    p.steps[i] = ok
    if ok then p.n = p.n + 1 end
  end
  local last = #a.steps > 0 and p.steps[#a.steps]
  p.done = (a.item ~= nil and keys[a.item] == true) or last or false
  if p.done then p.n = p.of end
  return p
end

-- Short text for a cell: "✓", "3/16", "–".
function QL:Cell(p)
  if p.done then return L.ATT_DONE end
  if p.n > 0 or p.at then return ("%d/%d"):format(p.n, p.of) end
  return L.ATT_NONE
end

-- Is the Attune addon here? Its own command opens it.
function QL:AttuneCommand() return ns.SlashCommand("/attune") end

function QL:OpenAttune()
  local fn = self:AttuneCommand()
  if fn then fn("") else ns:Toast(nil, L.ATTUNE, L.ATTUNE_MISSING) end
end

---------------------------------------------------------------------------
-- Dungeon quests
---------------------------------------------------------------------------
-- The quests of a dungeon for this fellowship's side: { { id, name } }.
function QL:DungeonQuests(f, key)
  local s, list = side(f), {}
  for _, q in ipairs(ns.DUNGEON_QUESTS[ns.BaseKey(key)] or {}) do
    if forSide({ side = q[3] }, s) then list[#list + 1] = { id = q[1], name = q[2] } end
  end
  return list
end

-- Per Hero: how many of the dungeon's quests they carry, and how many they have not done yet.
-- { { name, have, open } } in the order given, or nil when the dungeon has no list.
function QL:DungeonStatus(f, key, names)
  local quests = self:DungeonQuests(f, key)
  if #quests == 0 then return nil end
  local out = {}
  for _, name in ipairs(names) do
    local h = Hr:Get(f, name) or {}
    local have, open = 0, 0
    for _, q in ipairs(quests) do
      if not (h.questsDone and h.questsDone[q.id]) then
        open = open + 1
        if h.quests and h.quests[q.id] then have = have + 1 end
      end
    end
    out[#out + 1] = { name = name, have = have, open = open }
  end
  return out
end

-- "Quests picked up: You 2/5, Brannic 0/6" (open quests only).
function QL:DungeonLine(f, key)
  local me, names = ns.Me(), {}
  names[1] = me
  for _, n in ipairs(F:Members(f)) do if n ~= me and not ns.Journey:Away(f, n) then names[#names + 1] = n end end
  local status = self:DungeonStatus(f, key, names)
  if not status then return nil end
  local parts = {}
  for _, s in ipairs(status) do
    parts[#parts + 1] = L.DQ_HERO:format(s.name == me and L.YOU_LABEL or ns.Short(s.name), s.have, s.open)
  end
  return L.DQ_LINE:format(table.concat(parts, ", "))
end

-- A level up that opens an attunement: a toast with where to see it (Quests → Attunements). In a fellowship or not.
function QL:OnLevelUp(newLevel)
  newLevel = tonumber(newLevel)
  if not newLevel then return end
  local s = SIDE[UnitFactionGroup("player") or ""]
  for _, a in ipairs(self:NewlyAvailable(s, newLevel - 1, newLevel)) do
    ns:Toast("attune", L.TOAST_ATTUNE_TITLE:format(a.name), a.kind == "raid" and L.TOAST_ATTUNE_RAID or L.TOAST_ATTUNE_KEY, "quests")
  end
end
ns:RegisterEvent("PLAYER_LEVEL_UP", function(_, level) QL:OnLevelUp(level) end)

-- A key picked up or used: share it with the quest log (sent only when something changed).
ns:RegisterEvent("BAG_UPDATE_DELAYED", function() if F:Current() then ns.Quests:Soon() end end)
