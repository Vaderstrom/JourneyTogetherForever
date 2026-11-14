-- Attunements and keys (SPEC §6) from our own lists (Data/QuestLists.lua), and dungeon quests from our own database
-- (Data/DungeonQuests.lua; the owner, 9 Nov 2026). Each Hero's addon checks
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
  for _, quests in pairs(ns.DUNGEON_CLASS_QUESTS) do for _, q in ipairs(quests) do add(q[1]) end end
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
    if forSide({ side = q[3] }, s) then list[#list + 1] = { id = q[1], name = ns.Quests.Name(q[1], q[2]) } end
  end
  self.made[id] = list
  return list
end

---------------------------------------------------------------------------
-- The Dungeons tab (U79): where each dungeon quest starts, in three groups
---------------------------------------------------------------------------
-- Where a quest starts, its levels and the chain to do first (Data/DungeonQuests.lua): the same
-- for every Adventurer (the owner, 9 Nov 2026: one source, never learned from play). nil for a quest on no list.
function QL:Start(id) return ns.QUEST_STARTS[id] end

local function statusOf(h, id)
  if h.questsDone and h.questsDone[id] then return "done" end
  return h.quests and h.quests[id] and "log" or "no"
end
QL.StatusOf = statusOf

-- How many steps of a quest's chain come before the run: those before the first that starts in the dungeon (that one
-- is done in the run), and at most one that is done in the run (run: it is taken before, The Drowned City for A Tale
-- Spun Around the Fire).
local function leadIn(st)
  local n = 0
  for _, s in ipairs(st.after or {}) do
    if s.inside then break end
    n = n + 1
    if s.run then break end
  end
  return n
end
-- A step before the run is ready when it is done, or in the log when it is done in the run or only has to be taken
-- (accept: Rig Wars).
local function stepReady(s, status) return status == "done" or ((s.run or s.accept) and status == "log") or false end
-- The group a quest belongs to: earlier when its chain has steps to do before the run (also when the quest itself
-- starts inside, as The Truth Comes Crashing Down does), else inside or pick by where it starts.
local function groupOf(st) return leadIn(st) > 0 and "earlier" or (st.inside and "inside" or "pick") end
QL.GroupOf = groupOf
-- A chain as one key: quests after exactly the same chain (U171: the Deadmines' Red Silk Bandanas and The Defias
-- Brotherhood) are one chain to start, each its own row (the owner, 12 Nov 2026). The whole chain, not only its steps
-- before the run: one that goes on otherwise inside counts as its own (The Truth Comes Crashing Down).
local function chainKey(st)
  local ids = {}
  for k, s in ipairs(st.after or {}) do ids[k] = s[1] end
  return table.concat(ids, ",")
end

-- A quest as a Dungeon page row, with name's status: { id, name, start, status, others, steps }.
local function questRow(f, q, name, others)
  local h = Hr:Get(f, name) or {}
  local st = QL:Start(q.id) or {}
  local x = { id = q.id, name = q.name, start = st, status = statusOf(h, q.id), others = others or {} }
  if st.after then
    x.steps = {}
    for _, s in ipairs(st.after) do
      x.steps[#x.steps + 1] = { id = s[1], name = ns.Quests.Name(s[1], s[2]), lvl = s.lvl, start = s, status = statusOf(h, s[1]) }
    end
  end
  return x
end

-- A dungeon's quests for this fellowship's side in three groups (SPEC §4.6): pick (pick up before you go), earlier
-- (a chain to start earlier) and inside (starts in the dungeon), each lowest level first. A quest: { id, name, start,
-- status (yours, or who's: "done", "log" or "no"), others (other Adventurers with it in their log), steps = { { id,
-- name, lvl, start (where it starts, as a quest start), status } } }. Quests after the same chain are a row each, with
-- their own status (the owner, 12 Nov 2026: one row said "Not yet" with all its steps done). nil when the dungeon has
-- no list.
function QL:Groups(f, key, who)
  local quests = self:DungeonQuests(f, key)
  if #quests == 0 then return nil end
  local me = who or ns.Me()
  local g = { pick = {}, earlier = {}, inside = {} }
  for _, q in ipairs(quests) do
    local others = {}
    for _, n in ipairs(F:Members(f)) do
      local h = n ~= me and Hr:Get(f, n)
      if h and h.quests and h.quests[q.id] then others[#others + 1] = n end
    end
    local x = questRow(f, q, me, others)
    local list = g[groupOf(x.start)]
    list[#list + 1] = x
  end
  -- Quests after one chain side by side, where the lowest of them would be (the owner, 12 Nov 2026: the Deadmines'
  -- Red Silk Bandanas and The Defias Brotherhood had Destruction in Deadmines between them).
  local first = {}
  for _, x in ipairs(g.earlier) do
    local c, l = chainKey(x.start), x.start.lvl or 99
    if not first[c] or l < first[c] then first[c] = l end
  end
  for k, list in pairs(g) do
    table.sort(list, function(a, b)
      if k == "earlier" then
        local ca, cb = chainKey(a.start), chainKey(b.start)
        if ca ~= cb then
          if first[ca] ~= first[cb] then return first[ca] < first[cb] end
          return ca < cb
        end
      end
      local la, lb = a.start.lvl or 99, b.start.lvl or 99
      if la ~= lb then return la < lb end
      return a.name < b.name
    end)
  end
  return g
end

-- Class quests with a part in the dungeon, for this fellowship's side (the owner, 14 Nov 2026): { { id, name, class } },
-- made once per side like DungeonQuests. A guide only: Who is ready, the To do and the toasts never count them.
function QL:ClassQuests(f, key)
  local s, base = side(f), ns.BaseKey(key)
  local id = "class:" .. (s or "-") .. ":" .. tostring(base)
  if self.made[id] then return self.made[id] end
  local list = {}
  for _, q in ipairs(ns.DUNGEON_CLASS_QUESTS[base] or {}) do
    if forSide({ side = q[3] }, s) then list[#list + 1] = { id = q[1], name = ns.Quests.Name(q[1], q[2]), class = q[4] } end
  end
  self.made[id] = list
  return list
end

-- The class quests the Dungeon page shows for who: those of who's class, and with all those of the fellowship's other
-- classes (the owner, 14 Nov 2026: "Yours + a toggle"). Rows as in Groups, with class, mine and names (the Adventurers
-- of that class, who first), the status that of names[1]; who's class first, then by class and level. Also how many
-- there are of the other Adventurers' classes, shown or not (the tick shows where there are some).
function QL:ClassRows(f, key, who, all)
  local byClass, mineClass = {}, select(2, Hr:ClassName(f, who))
  for _, n in ipairs(F:Members(f)) do
    local _, token = Hr:ClassName(f, n)
    if token then
      byClass[token] = byClass[token] or {}
      table.insert(byClass[token], n == who and 1 or #byClass[token] + 1, n)
    end
  end
  local rows, others = {}, 0
  for _, q in ipairs(self:ClassQuests(f, key)) do
    local names, mine = byClass[q.class], q.class == mineClass
    if names and not mine then others = others + 1 end
    if names and (mine or all) then
      local x = questRow(f, q, names[1])
      x.class, x.mine, x.names = q.class, mine, names
      rows[#rows + 1] = x
    end
  end
  table.sort(rows, function(a, b)
    if a.mine ~= b.mine then return a.mine end
    if a.class ~= b.class then return a.class < b.class end
    local la, lb = a.start.lvl or 99, b.start.lvl or 99
    if la ~= lb then return la < lb end
    return a.name < b.name
  end)
  return rows, others
end

-- The level from which a quest can be taken: our data's, else this many under its level.
-- shortcut: the 4 is a rule of thumb for a chain's steps, whose start level our data does not give.
QL.TAKE_BELOW = 4
local function opensAt(st, dungeonFrom)
  return st.min or (st.lvl or dungeonFrom) - QL.TAKE_BELOW
end

-- Who is ready for a dungeon (U98, the owner, 8 Nov 2026): every Start-early chain ready up to the dungeon quest, or up
-- to the run (stepReady; or the quest itself in the log or done), and every Pick-up quest in the log or done, by
-- name's shared quest log. A quest after a chain done to its end is one to pick up too (the owner, 13 Nov 2026: "Ready"
-- came with Red Silk Bandanas and The Defias Brotherhood still at their givers). A quest to pick up counts from the
-- level it opens at for name (the owner, 14 Nov 2026: Razorfen Downs' Bring the Light opens at 39, its chapter's floor
-- is 37). The same on every PC: it reads only the shipped data, the shared logs and levels.
-- { early, earlyOf (chains), pick, pickOf, quests (earlier and pick-up quests), ready, shares, toPick (the starts of
-- the quests still to pick up) }; nil when there is nothing to get ready (no list, or only quests inside).
function QL:Ready(f, key, name)
  -- (A level not known yet leaves nothing out: Hr:Level would say 1; the review of 14 Nov 2026.)
  local h, counted = Hr:Get(f, name) or {}, nil
  local lvl = tonumber(h.level or (f.members[name] or {}).level)
  local from = (ns.Dungeon(key) or {})[3] or 0
  local r = { early = 0, earlyOf = 0, pick = 0, pickOf = 0, shares = {}, quests = 0, toPick = {} }
  local chains = {} -- (a chain two quests share counts once, U171)
  -- A shareable quest to pick up that another Adventurer counted for the chapter has in their log is ready for you too,
  -- shared at the entrance (U177, the owner, 10 Nov 2026): shares = { { id, by } }.
  local function sharer(q, st)
    if not st.share then return nil end
    counted = counted or ns.Journey:Counted(f)
    for _, n in ipairs(counted) do
      if statusOf(Hr:Get(f, n) or {}, q.id) == "log" then return n end
    end
  end
  -- A quest to pick up: in the log or done, or shared at the entrance (U177; a quest after a chain too, the release
  -- review of 13 Nov 2026); else still at its giver (toPick).
  local function pickUp(q, st, ok)
    r.pickOf = r.pickOf + 1
    local by = not ok and sharer(q, st)
    if by then r.shares[#r.shares + 1] = { q.id, by } end
    if ok or by then r.pick = r.pick + 1 else r.toPick[#r.toPick + 1] = st end
  end
  for _, q in ipairs(self:DungeonQuests(f, key)) do
    local st = self:Start(q.id) or {}
    local g = groupOf(st)
    local ok = statusOf(h, q.id) ~= "no"
    local later = not ok and lvl ~= nil and lvl < opensAt(st, from) -- (not open to name yet: counted from its level)
    -- (Quests, not chains: the To do counts them. A chain's own quest counts while its chain does, the review of 14 Nov
    -- 2026: "Ready: your 0 quests are in your log."; only a quest to pick up that is not open yet is left out.)
    if g == "earlier" or (g == "pick" and not later) then r.quests = r.quests + 1 end
    if g == "pick" then
      if not later then pickUp(q, st, ok) end
    elseif g == "earlier" then
      local chain = ok
      if not ok then
        chain = true
        for k = 1, leadIn(st) do
          if not stepReady(st.after[k], statusOf(h, st.after[k][1])) then chain = false break end
        end
        -- Its whole chain done and the quest itself still at its giver: a quest to pick up (the owner, 13 Nov 2026).
        -- Every step, not only those before the run (Uldaman's The Lost Tablets of Will comes after A Sign of Hope, done
        -- in the run, and four more); one that starts inside is taken in the run.
        local allDone = chain and not st.inside
        for _, s in ipairs(allDone and st.after or {}) do
          if statusOf(h, s[1]) ~= "done" then allDone = false break end
        end
        if allDone and later then r.quests = r.quests - 1 elseif allDone then pickUp(q, st, false) end
      end
      local c = chainKey(st)
      chains[c] = chains[c] or chain
    end
  end
  for _, ok in pairs(chains) do
    r.earlyOf = r.earlyOf + 1
    if ok then r.early = r.early + 1 end
  end
  if r.earlyOf + r.pickOf == 0 then return nil end
  r.ready = r.early == r.earlyOf and r.pick == r.pickOf
  return r
end

-- A quest's status as an icon and a coloured word (U101): Done in green, In your log in gold, Not yet in grey. The icon
-- stands before the quest's name, the word first on the line under it (the owner, 11 Nov 2026: at the line's end, a
-- second icon and "Not" / "yet" broke over two lines).
QL.STATUS = {
  done = { "Interface\\RaidFrame\\ReadyCheck-Ready", "3E7A3A", "DQ_DONE" },
  log = { "Interface\\Icons\\INV_Scroll_03", "B8742A", "DQ_IN_LOG" },
  no = { "Interface\\COMMON\\Indicator-Gray", nil, "DQ_NOT_YET" }, -- (in the line's own colour: a role is no hex)
}
function QL.StatusText(status, word)
  local s = QL.STATUS[status] or QL.STATUS.no
  local text = word or L[s[3]]
  return s[2] and ("|cff%s%s|r"):format(ns.Theme:HexFor(s[2]), text) or text
end

-- Where a quest starts, in words: "Scout Riell, Westfall", an item, inside, or not known yet.
function QL.WhereText(st)
  if st.inside then return st.item and L.DQ_ITEM_INSIDE:format(st.item) or L.DQ_INSIDE_LINE end
  if st.item then return L.DQ_ITEM:format(st.item) end
  local place = st.zone -- (the spot's numbers only in Pin on map's tooltip, U160)
  if st.by and place then return L.DQ_BY_AT:format(st.by, place) end
  return st.by or place or L.DQ_WHERE_UNKNOWN
end

-- Opens the dungeon's own page, where its quests are (U96).
function QL:Open(key) ns.DungeonPage:Open(key) end

-- A zone's map by its name (the data names zones, so it holds in any client); a start with a spot carries its map.
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

-- Show on map (the owner, 14 Nov 2026: "Click the cross", in our own look): wherever the spot is known, the world map
-- opens at its zone with our mark on it, and a click on the mark sets the waypoint (ns.MapMark), with Questie running
-- too (the owner, 10 Nov 2026); with Questie running and no spot, the zone's world map, where Questie marks the quest
-- giver. True when there is something to show.
function QL:CanPin(st)
  if st.x and st.y then return true end
  return ns.Quests:QuestieState() == "on" and self:MapOf(st) ~= nil
end

-- st: where it starts (a quest's start, or a chain step's; a dungeon's entrance); title: what the mark names (the
-- quest). In combat the map does not open: the place goes to chat.
function QL:Pin(st, title)
  st = st or {}
  local map = self:MapOf(st)
  if st.x and st.y then
    if map and ns.MapMark:Show(st, map, title) then return "mark" end
    ns:Print(QL.PlaceLine(st))
    return "chat"
  end
  if ns.Quests:QuestieState() == "on" and map and OpenWorldMap and not InCombatLockdown() then
    OpenWorldMap(map)
    return "map"
  end
  return nil
end

-- The game's own map pin, followed (WoW Forever allows it: the check of 10 Nov 2026, Westfall).
-- shortcut: no TomTom; where the game allows no waypoint on that map, the place goes to chat.
-- Who and where, with the spot: "Scout Riell, Westfall 56.7, 47.4" (chat and the map mark's tooltip).
function QL.PlaceLine(st) return L.DQ_PIN_WHERE:format(st.by or st.zone or "", st.zone or "", st.x, st.y) end

function QL:Waypoint(st, map)
  local where = QL.PlaceLine(st)
  if map and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(map) and UiMapPoint then
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, st.x / 100, st.y / 100))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    ns:Print(L.DQ_PIN_SET:format(where))
    return "waypoint"
  end
  ns:Print(where)
  return "chat"
end

-- Steps for later dungeons (U136, U140; the owner, 10 Nov 2026): for each dungeon of a chapter after n (once, by its
-- base key: Blackrock Depths is in two), the next step before the run of each of its prequest chains not done yet, once
-- your level reaches that step's level and it is within chapter n's cap. A chain under way counts until it is done (its
-- step in your log too), whatever its level, and comes first; a chain two quests share is one step. Quests you only pick up wait for their dungeon's own
-- chapter. The next chapter's dungeons that may be run now (If you like) and dungeons already cleared are left out.
-- Nearest chapter first: { { x (ChapterList entry), chapter, steps = { { id, name, lvl, k, of (steps before the run),
-- status, under } }, open (steps listed) } }.
function QL:Later(f, n, who)
  local J, chapters = ns.Journey, f.journey.chapters
  local ch = chapters[n]
  if not ch then return {} end
  who = who or ns.Me()
  local mine, level = Hr:Get(f, who) or {}, Hr:Level(f, who)
  local seen, out = {}, {}
  for _, x in ipairs(J:ChapterList(f, n)) do seen[ns.BaseKey(x.key)] = true end
  for m = n + 1, #chapters do
    for _, x in ipairs(J:ChapterList(f, m)) do
      local base = ns.BaseKey(x.key)
      if not x.early and not seen[base] then
        seen[base] = true
        local steps, took = {}, {}
        for _, q in ipairs(J:Cleared(f, x.key) and {} or self:DungeonQuests(f, x.key)) do
          local st = self:Start(q.id) or {}
          if groupOf(st) == "earlier" and statusOf(mine, q.id) == "no" then
            local of = leadIn(st)
            for k = 1, of do
              local s = st.after[k]
              local ss = statusOf(mine, s[1])
              if not stepReady(s, ss) then
                local lvl = s.lvl or st.lvl or x.d[3]
                -- Under way (an earlier step done, or this one in your log): it stays whatever its level (review of
                -- 1.7.0: Blackrock Depths' step 3 is level 59, step 2 level 54).
                local under = k > 1 or ss ~= "no"
                if (under or (lvl <= ch.cap and level >= lvl)) and not took[s[1]] then
                  took[s[1]] = true
                  steps[#steps + 1] = { id = s[1], name = ns.Quests.Name(s[1], s[2]), lvl = lvl, k = k, of = of, status = ss, under = under }
                end
                break
              end
            end
          end
        end
        if #steps > 0 then
          table.sort(steps, function(a, b)
            if a.under ~= b.under then return a.under end
            if a.lvl ~= b.lvl then return a.lvl < b.lvl end
            return a.name < b.name
          end)
          out[#out + 1] = { x = x, chapter = m, steps = steps, open = #steps }
        end
      end
    end
  end
  return out
end

-- A later dungeon's first step in words (U140): "Testing the Wells: open now." or, for a chain under way, "The Defias
-- Brotherhood, step 3 of 6."; the others are on its Dungeon page (a second one ran out of the row; check of 10 Nov 2026).
function QL.LaterLine(e)
  local s = e.steps[1]
  if s.k == 1 and s.status == "no" then return L.LATER_NOW:format(s.name) end
  return L.LATER_STEP:format(s.name, s.k, s.of)
end

-- "Pick up 2 quests in Westfall before the run.", for the quests that start at these starts (each zone once).
function QL.PickText(starts)
  local zones, seen = {}, {}
  for _, st in ipairs(starts) do
    if st.zone and not seen[st.zone] then seen[st.zone] = true; zones[#zones + 1] = st.zone end
  end
  local n = #starts == 1 and L.DQ_1_QUEST or L.DQ_N_QUESTS:format(#starts)
  return #zones > 0 and L.TOAST_DQ_PICK_IN:format(n, table.concat(zones, L.AND)) or L.TOAST_DQ_PICK:format(n)
end

-- The reminder (U79, folds in U69): once per dungeon of the current or the next chapter, when its first quest to pick
-- up opens to you (your own chapter's dungeons only) or you reach a chain's next step's level. Never in combat (it
-- waits), never twice (ns.char.dqToasted).
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
        local starts, chain = {}, nil
        -- (Quests you only pick up: for your own chapter's dungeons, not the next one's; the owner, 10 Nov 2026.)
        for _, q in ipairs(n == cur and g.pick or {}) do
          if q.status == "no" and level >= opensAt(q.start, x.d[3]) then starts[#starts + 1] = q.start end
        end
        for _, q in ipairs(g.earlier) do
          if not chain and q.status == "no" then
            for k, s in ipairs(q.steps) do
              if k > leadIn(q.start) then break end -- (a step inside is done in the run)
              if not stepReady(s.start, s.status) then
                -- (At the step's own level, as the To do and Coming up: the owner, 10 Nov 2026.)
                if level >= (s.lvl or q.start.lvl or x.d[3]) then chain = s.name end
                break
              end
            end
          end
        end
        if #starts > 0 or chain then
          ns.char.dqToasted[key] = true
          local parts = {}
          if #starts > 0 then parts[1] = QL.PickText(starts) end
          if chain then parts[#parts + 1] = L.TOAST_DQ_CHAIN:format(chain) end
          ns:Toast("dquest", x.d[2], table.concat(parts, " "), function() QL:Open(x.key) end, { dungeon = x.key })
        end
      end
    end
  end
end
-- (At a level-up only, from QL:OnLevelUp: at login a character long past those levels would get a toast for each.)

-- Is this quest on a dungeon's list? (Quests.lua: a dungeon's quest is done in the run, U110.)
function QL:IsDungeonQuest(id)
  if not self.dungeonIDs then
    self.dungeonIDs = {}
    for _, quests in pairs(ns.DUNGEON_QUESTS) do for _, q in ipairs(quests) do self.dungeonIDs[q[1]] = true end end
  end
  return self.dungeonIDs[id] == true
end
-- (Addons before 1.5 sent where a dungeon quest started and its XP, QSTART: Comm drops a message nobody handles.)

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
