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
  -- (The steps of a chain to start earlier too: the Dungeons tab shows who has done each.)
  for _, st in pairs(ns.QUEST_STARTS) do for _, s in ipairs(st.after or {}) do add(s[1]) end end
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
-- The quests of a dungeon for this fellowship's side: { { id, name } }. The lists never change while playing, so each
-- is made once per side and shared: read it, never change it (ChapterList made them again on every call, for every
-- dungeon; code review of 1.2.0).
QL.made = {}
function QL:DungeonQuests(f, key)
  local s, base = side(f), ns.BaseKey(key)
  local id = (s or "-") .. ":" .. tostring(base)
  local list = self.made[id]
  if list then return list end
  list = {}
  for _, q in ipairs(ns.DUNGEON_QUESTS[base] or {}) do
    if forSide({ side = q[3] }, s) then list[#list + 1] = { id = q[1], name = q[2] } end
  end
  self.made[id] = list
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

---------------------------------------------------------------------------
-- The Dungeons tab (U79): where each dungeon quest starts, in three groups
---------------------------------------------------------------------------
-- Where a quest starts: the shipped data (Data/QuestLists.lua) wins, then the starts harvested from play
-- (Data/QuestChains.lua), then what this account learned (ns.db.questStarts). nil when none knows it.
function QL:Start(id)
  local ship = ns.QUEST_STARTS[id]
  local harvested = ns.QUEST_CHAINS and ns.QUEST_CHAINS.starts and ns.QUEST_CHAINS.starts[id]
  local learned = ns.db.questStarts and ns.db.questStarts[id]
  if not (harvested or learned) then return ship end
  local out = {}
  for _, src in ipairs({ learned or {}, harvested or {}, ship or {} }) do for k, v in pairs(src) do out[k] = v end end
  return out
end

local function statusOf(h, id)
  if h.questsDone and h.questsDone[id] then return "done" end
  return h.quests and h.quests[id] and "log" or "no"
end

-- The group a quest belongs to by where it starts: inside, earlier (a chain) or pick.
local function groupOf(st) return st.inside and "inside" or (st.after and "earlier" or "pick") end

-- A dungeon's quests for this fellowship's side in three groups (SPEC §4.6): pick (pick up before you go), earlier
-- (a chain to start earlier) and inside (starts in the dungeon), each lowest level first. A quest: { id, name, start,
-- status (yours: "done", "log" or "no"), others (other Adventurers with it in their log), steps = { { id, name, lvl,
-- status } } }. nil when the dungeon has no list.
function QL:Groups(f, key)
  local quests = self:DungeonQuests(f, key)
  if #quests == 0 then return nil end
  local me = ns.Me()
  local mine = Hr:Get(f, me) or {}
  local g = { pick = {}, earlier = {}, inside = {} }
  for _, q in ipairs(quests) do
    local st = self:Start(q.id) or {}
    local x = { id = q.id, name = q.name, start = st, status = statusOf(mine, q.id), others = {} }
    for _, n in ipairs(F:Members(f)) do
      local h = n ~= me and Hr:Get(f, n)
      if h and h.quests and h.quests[q.id] then x.others[#x.others + 1] = n end
    end
    if st.after then
      x.steps = {}
      for _, s in ipairs(st.after) do x.steps[#x.steps + 1] = { id = s[1], name = s[2], lvl = s[3], status = statusOf(mine, s[1]) } end
    end
    local list = g[groupOf(st)]
    list[#list + 1] = x
  end
  for _, list in pairs(g) do
    table.sort(list, function(a, b)
      local la, lb = a.start.lvl or 99, b.start.lvl or 99
      if la ~= lb then return la < lb end
      return a.name < b.name
    end)
  end
  return g
end

-- How many quests of each group you have not done: pick, earlier, inside (nil when the dungeon has no list).
-- Only counted: the Dungeons tab asks this for every dungeon of the journey at each redraw, and building their groups
-- (every Adventurer's log, the chain steps, the sorting) each time was too much (code review of 1.2.0).
function QL:Counts(f, key)
  local quests = self:DungeonQuests(f, key)
  if #quests == 0 then return nil end
  local mine = Hr:Get(f, ns.Me()) or {}
  local n = { pick = 0, earlier = 0, inside = 0 }
  for _, q in ipairs(quests) do
    if statusOf(mine, q.id) ~= "done" then
      local g = groupOf(self:Start(q.id) or {})
      n[g] = n[g] + 1
    end
  end
  return n.pick, n.earlier, n.inside
end

-- "4 quests to pick up  ·  2 to start earlier" (only quests you have not done), or nil; then the two counts (nil
-- without a quest list).
function QL:CountLine(f, key)
  local pick, earlier = self:Counts(f, key)
  if not pick or pick + earlier == 0 then return nil, pick, earlier end
  local parts = {}
  if pick > 0 then parts[1] = pick == 1 and L.DQ_PICK_1 or L.DQ_PICK_N:format(pick) end
  if earlier > 0 then parts[#parts + 1] = L.DQ_EARLIER_N:format(earlier) end
  return table.concat(parts, "  ·  "), pick, earlier
end

-- Where a quest starts, in words: "Scout Riell, Westfall 56.7, 47.4", an item, inside, or not known yet.
function QL.WhereText(st)
  if st.inside then return st.item and L.DQ_ITEM_INSIDE:format(st.item) or L.DQ_INSIDE_LINE end
  if st.item then return L.DQ_ITEM:format(st.item) end
  local place = st.zone and (st.x and L.DQ_AT:format(st.zone, st.x, st.y) or st.zone)
  if st.by and place then return L.DQ_BY_AT:format(st.by, place) end
  return st.by or place or L.DQ_WHERE_UNKNOWN
end

-- Opens the Quests page on the Dungeons tab at this dungeon.
function QL:Open(key)
  ns.Window.questDungeon = key
  ns.Window:Open("quests")
end

-- A zone's map by its name (the data names zones, so it holds in any client); learned starts carry their map.
QL.maps = {}
function QL:MapOf(st)
  if st.map then return st.map end
  local zone = st.zone
  if not zone then return nil end
  if QL.maps[zone] == nil then
    if not (C_Map and C_Map.GetMapChildrenInfo and Enum and Enum.UIMapType) then return nil end
    QL.maps[zone] = false
    local ok, list = pcall(C_Map.GetMapChildrenInfo, 947, Enum.UIMapType.Zone, true)
    for _, m in ipairs(ok and type(list) == "table" and list or {}) do
      if m.name == zone then QL.maps[zone] = m.mapID break end
    end
  end
  return QL.maps[zone] or nil
end

-- Pin on map: with Questie running, the zone's world map (Questie's pins show the quest giver); else a waypoint at
-- the quest giver, after asking. True when there is something to pin.
function QL:CanPin(st)
  if ns.Quests:QuestieState() == "on" then return self:MapOf(st) ~= nil end
  return st.x ~= nil and st.y ~= nil
end

function QL:Pin(id)
  local st = self:Start(id) or {}
  local map = self:MapOf(st)
  if ns.Quests:QuestieState() == "on" and map and OpenWorldMap and not InCombatLockdown() then
    OpenWorldMap(map)
    return "map"
  end
  if not (st.x and st.y) then return nil end
  ns.Window:Confirm(L.DQ_PIN_ASK, L.DQ_PIN_OK, function() QL:Waypoint(st, map) end)
  return "ask"
end

-- shortcut: no TomTom; where the game allows no waypoint on that map (DungeonJournal's notes say Forever may not),
-- the place goes to chat. Check C_Map.SetUserWaypoint in Forever, then decide whether TomTom is worth it.
function QL:Waypoint(st, map)
  local where = L.DQ_PIN_WHERE:format(st.by or st.zone or "", st.zone or "", st.x, st.y)
  if map and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(map) and UiMapPoint then
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, st.x / 100, st.y / 100))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    ns:Print(L.DQ_PIN_SET:format(where))
    return "waypoint"
  end
  ns:Print(where)
  return "chat"
end

-- The level from which a quest can be taken: the sources' own, else this many under its level.
-- shortcut: the 4 is a rule of thumb where the sources give no start level; learned levels would be exact.
QL.TAKE_BELOW = 4
local function opensAt(st, dungeonFrom)
  return st.min or (st.lvl or dungeonFrom) - QL.TAKE_BELOW
end

-- The reminder (U79, folds in U69): once per dungeon of the current or the next chapter, when its first quest to pick
-- up or a chain's first step opens to you. Never in combat (it waits), never twice (ns.char.dqToasted).
function QL:Remind(level)
  local f = F:Current()
  level = tonumber(level) or UnitLevel("player")
  if not f or not level then return end
  if ns.Combat:InCombat() then
    if not self.remindLater then
      self.remindLater = true
      ns.Combat:AfterCombat(function() QL.remindLater = nil; QL:Remind(level) end)
    end
    return
  end
  ns.char.dqToasted = ns.char.dqToasted or {}
  local J, cur = ns.Journey, ns.Journey:CurrentIndex(f)
  for n = cur, cur + 1 do
    for _, x in ipairs(f.journey.chapters[n] and J:ChapterList(f, n) or {}) do
      local key = ns.BaseKey(x.key)
      local g = not ns.char.dqToasted[key] and self:Groups(f, x.key)
      if g then
        local pick, zones, seen, chain = 0, {}, {}, nil
        for _, q in ipairs(g.pick) do
          if q.status == "no" and level >= opensAt(q.start, x.d[3]) then
            pick = pick + 1
            if q.start.zone and not seen[q.start.zone] then seen[q.start.zone] = true; zones[#zones + 1] = q.start.zone end
          end
        end
        for _, q in ipairs(g.earlier) do
          if not chain and q.status == "no" then
            for _, s in ipairs(q.steps) do
              if s.status ~= "done" then
                if level >= (s.lvl and s.lvl - QL.TAKE_BELOW or opensAt(q.start, x.d[3])) then chain = s.name end
                break
              end
            end
          end
        end
        if pick > 0 or chain then
          ns.char.dqToasted[key] = true
          local parts = {}
          if pick > 0 then
            local n1 = pick == 1 and L.DQ_1_QUEST or L.DQ_N_QUESTS:format(pick)
            parts[1] = #zones > 0 and L.TOAST_DQ_PICK_IN:format(n1, table.concat(zones, L.AND)) or L.TOAST_DQ_PICK:format(n1)
          end
          if chain then parts[#parts + 1] = L.TOAST_DQ_CHAIN:format(chain) end
          ns:Toast("dquest", x.d[2], table.concat(parts, " "), function() QL:Open(x.key) end, { dungeon = x.key })
        end
      end
    end
  end
end
-- (At a level-up only, from QL:OnLevelUp: at login a character long past those levels would get a toast for each.)

-- Learned in game (U79): a dungeon quest picked up where nobody knows where it starts notes the quest giver and the
-- place (or that it started inside); a hand-in notes its XP (U78). Both go to the fellowship (QSTART) and are
-- harvested into Data/QuestChains.lua like chain links (tools/harvest-quest-chains.ps1).
function QL:IsDungeonQuest(id)
  if not self.dungeonIDs then
    self.dungeonIDs = {}
    for _, quests in pairs(ns.DUNGEON_QUESTS) do for _, q in ipairs(quests) do self.dungeonIDs[q[1]] = true end end
  end
  return self.dungeonIDs[id] == true
end

-- A start or XP sent by another Adventurer, checked (it comes from outside): returns a clean copy, or nil.
local function cleanStart(s)
  if type(s) ~= "table" then return nil end
  local out = {}
  if s.inside == true then out.inside = true end
  if type(s.by) == "string" and #s.by <= 60 then out.by = s.by end
  if type(s.zone) == "string" and #s.zone <= 60 then out.zone = s.zone end
  local map, x, y = tonumber(s.map), tonumber(s.x), tonumber(s.y)
  if map and x and y and x >= 0 and x <= 100 and y >= 0 and y <= 100 then out.map, out.x, out.y = map, x, y end
  return next(out) and out or nil
end
QL.CleanStart = cleanStart

function QL:Keep(id, s, xp)
  ns.db.questStarts, ns.db.questXP = ns.db.questStarts or {}, ns.db.questXP or {}
  local changed = false
  local known = self:Start(id)
  if s and not (known and (known.x or known.inside or known.item)) then ns.db.questStarts[id] = s; changed = true end
  -- The most anyone was given: a hand-in far above the quest's level gives less.
  xp = tonumber(xp) and math.floor(xp)
  if xp and xp > 0 and xp < 100000 and xp > (ns.db.questXP[id] or 0) then ns.db.questXP[id] = xp; changed = true end
  return changed
end

function QL:Share(id, s, xp)
  local f = F:Current()
  if f then ns.Comm:SendAll(ns.Others(f), "QSTART", { fid = f.id, id = id, s = s, xp = xp }) end
end

-- Where I stand as a quest's start: the quest giver, the map and the position; inside a dungeon only that. nil
-- without a quest giver (an item's quest: where I stood says nothing), and for a quest another player shared.
function QL:Here()
  for _, unit in ipairs({ "questnpc", "npc" }) do
    if UnitExists(unit) and UnitIsPlayer(unit) then return nil end
  end
  if IsInInstance() then return { inside = true } end
  local by = UnitName("npc") or UnitName("questnpc")
  if type(by) ~= "string" or ns.Secret(by) then return nil end
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local pos = map and C_Map.GetPlayerMapPosition(map, "player")
  local info = map and C_Map.GetMapInfo(map)
  local s = { by = by }
  if pos and info then
    local x, y = pos:GetXY()
    s.map, s.zone = map, info.name
    s.x, s.y = math.floor(x * 1000 + 0.5) / 10, math.floor(y * 1000 + 0.5) / 10
  end
  return cleanStart(s)
end

ns:RegisterEvent("QUEST_ACCEPTED", function(_, a, b)
  local id = tonumber(b) or tonumber(a) -- Classic: (log index, questID); retail: (questID)
  if not (id and QL:IsDungeonQuest(id)) then return end
  local s = QL:Here()
  if s and QL:Keep(id, s) then QL:Share(id, s) end
end)

ns:RegisterEvent("QUEST_TURNED_IN", function(_, questID, xp)
  local id = tonumber(questID)
  if not (id and QL:IsDungeonQuest(id)) or ns.Secret(xp) then return end
  if QL:Keep(id, nil, xp) then QL:Share(id, nil, xp) end
end)

ns.Comm:On("QSTART", function(sender, d)
  if type(d) ~= "table" then return end
  local f, id = F:Get(d.fid), tonumber(d.id)
  if not (f and f.members[sender] and id and QL:IsDungeonQuest(id)) then return end
  QL:Keep(id, cleanStart(d.s), not ns.Secret(d.xp) and d.xp or nil)
end)

-- The place an attunement or key belongs to, for its picture (U8, 31 Oct 2026): the raid, the dungeon the key drops in
-- (the Dire Maul key: Dire Maul East, not the Deadmines), or its own key. A place without a picture keeps the icon.
function QL.PlaceOf(a) return a.raid or a.from or a.key end

-- A level up that opens an attunement: a toast with where to see it (Quests → Attunements). In a fellowship or not.
function QL:OnLevelUp(newLevel)
  newLevel = tonumber(newLevel)
  if not newLevel then return end
  local s = SIDE[UnitFactionGroup("player") or ""]
  for _, a in ipairs(self:NewlyAvailable(s, newLevel - 1, newLevel)) do
    ns:Toast("attune", L.TOAST_ATTUNE_TITLE:format(a.name), a.kind == "raid" and L.TOAST_ATTUNE_RAID or L.TOAST_ATTUNE_KEY, "quests",
      { dungeon = QL.PlaceOf(a) })
  end
  self:Remind(newLevel)
end
ns:RegisterEvent("PLAYER_LEVEL_UP", function(_, level) C_Timer.After(ns.LEVEL_UP.attune, function() QL:OnLevelUp(level) end) end)

-- A key picked up or used: share it with the quest log (sent only when something changed).
ns:RegisterEvent("BAG_UPDATE_DELAYED", function() if F:Current() then ns.Quests:Soon() end end)
