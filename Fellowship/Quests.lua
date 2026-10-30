-- Quests (SPEC §4.6, the mockup's qItems / qd): every Hero shares their quest log, so the fellowship sees which
-- quests and quest chains they share and how far each Hero is.
--   QUESTS   my quest log { [questID] = { t (title), z (zone), l (level), h (have), g (goal), k (kill quest), o
--            (objective) } }, the chain quests I have done, and chain links I know. With HELLO / HI, and 15
--            seconds after the log changes (only when something changed).
--   GRPQ     "Ask to group up" for a quest.
-- Chains are learned: when a Hero hands in a quest and accepts the next one from the same NPC within a minute, the
-- two are linked (ns.db.questLinks, shared with the other Heroes). Classic Era and retail quest APIs both work.
local _, ns = ...
local L = ns.L
local F, Comm = ns.Fellowship, ns.Comm
local Q = { SEND_DELAY = 15, LINK_WITHIN = 60 }
ns.Quests = Q

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) end

local function db()
  ns.db.questLinks = ns.db.questLinks or {}
  ns.db.questAlts = ns.db.questAlts or {}
  ns.db.questTitles = ns.db.questTitles or {}
  ns.db.questZones = ns.db.questZones or {}
  return ns.db
end

-- A learned link from quest a to quest b. The first next quest seen stays; a different one is kept as a branch
-- (questAlts), so two possible follow-ups no longer replace each other.
function Q:AddLink(a, b)
  a, b = tonumber(a), tonumber(b)
  if not a or not b or a == b then return end
  local d = db()
  local cur = d.questLinks[a]
  if not cur then d.questLinks[a] = b return end
  if cur == b then return end
  local alts = d.questAlts[a] or {}
  for _, x in ipairs(alts) do if x == b then return end end
  if #alts < 4 then alts[#alts + 1] = b end
  d.questAlts[a] = alts
end

-- Every chain link the addon knows, from four sources (docs/QUEST-CHAINS.md), weakest first:
--   Questie's database when the player has Questie (read at run time only: never saved, shared or harvested),
--   the chains we ship (Data/QuestChains.lua), and what this account learned (the game's quest lines included).
-- Returns links[a] = b and alts[a] = { other next quests }.
function Q:Links()
  local d, ship = db(), ns.QUEST_CHAINS or {}
  local links, alts = {}, {}
  for a, b in pairs(self.questie or {}) do links[a] = b end
  for a, b in pairs(ship.links or {}) do links[a] = b end
  for a, b in pairs(d.questLinks) do links[a] = b end
  for _, src in ipairs({ ship.alts or {}, d.questAlts }) do
    for a, list in pairs(src) do
      alts[a] = alts[a] or {}
      for _, b in ipairs(list) do if b ~= links[a] then alts[a][#alts[a] + 1] = b end end
    end
  end
  return links, alts
end

-- The game's own title of a quest (C_QuestLog), saved once known. Not cached yet: the game is asked to load it and
-- the book refreshes when it arrives (QUEST_DATA_LOAD_RESULT). Chains showed "#28767" for every quest nobody had
-- in their log (seen in the tour).
Q.titleAsked = {}
local function gameTitle(id)
  local QL = C_QuestLog
  if not (QL and QL.GetTitleForQuestID) then return nil end
  local ok, t = pcall(QL.GetTitleForQuestID, id)
  if ok and type(t) == "string" and t ~= "" and not secret(t) then
    db().questTitles[id] = t
    return t
  end
  if QL.RequestLoadQuestByID and not Q.titleAsked[id] then
    Q.titleAsked[id] = true
    pcall(QL.RequestLoadQuestByID, id)
  end
end

local function knownTitle(id)
  local ship = ns.QUEST_CHAINS and ns.QUEST_CHAINS.titles or {}
  local t = db().questTitles[id] or ship[id] or gameTitle(id)
  if t then return t end
  -- Questie's name for it, for this session only (never saved: see questieDB below).
  local qdb = Q.qdb
  if qdb then
    local ok, name = pcall(qdb.QueryQuestSingle, id, "name")
    if ok and type(name) == "string" and name ~= "" then return name end
  end
end

-- A title the game was asked for has arrived: show it.
ns:RegisterEvent("QUEST_DATA_LOAD_RESULT", function(_, id, ok)
  if ok and Q.titleAsked[id] and gameTitle(id) and ns.Window and ns.Window.RefreshSoon then ns.Window:RefreshSoon() end
end)

---------------------------------------------------------------------------
-- Chains from the game and from Questie
---------------------------------------------------------------------------
-- The game's own quest lines (C_QuestLine; Forever has them only for its new quests so far): each line's quests in
-- order are linked, as if learned. Asked once per line per session.
Q.linesSeen = {}
function Q:FromQuestLines(ids)
  local QL = C_QuestLine
  if not (QL and QL.GetQuestLineInfo and QL.GetQuestLineQuests) then return end
  for id in pairs(ids) do
    local ok, info = pcall(QL.GetQuestLineInfo, id)
    local line = ok and type(info) == "table" and info.questLineID
    if line and not self.linesSeen[line] then
      self.linesSeen[line] = true
      local ok2, list = pcall(QL.GetQuestLineQuests, line)
      if ok2 and type(list) == "table" then
        for i = 1, #list - 1 do self:AddLink(list[i], list[i + 1]) end
      end
    end
  end
end

-- Questie (another addon, GPL) when the player has it: its next and previous quest of each quest in the log. Kept
-- for this session only (self.questie), never saved, sent or harvested, so nothing of Questie's database ends up in
-- this addon or its data (which stay MIT).
-- Asked again until found: Questie may load after this addon.
local function questieDB()
  if Q.qdb then return Q.qdb end
  local loader = QuestieLoader
  if type(loader) == "table" and loader.ImportModule then
    local ok, m = pcall(loader.ImportModule, loader, "QuestieDB")
    if ok and type(m) == "table" and m.QueryQuestSingle then Q.qdb = m end
  end
  return Q.qdb
end

-- Questie is the recommended companion addon for the quest features (decided 27 Oct 2026): "on" (its quest data
-- answers), "off" (installed, but not running here: disabled, or not made for this game version) or "none".
function Q:QuestieState()
  if questieDB() then return "on" end
  local A = C_AddOns
  if not A then return "none" end
  if A.DoesAddOnExist then
    local ok, exists = pcall(A.DoesAddOnExist, "Questie")
    if ok then return exists and "off" or "none" end
  end
  if A.GetAddOnInfo then
    local ok, name, _, _, _, reason = pcall(A.GetAddOnInfo, "Questie")
    if ok and name and reason ~= "MISSING" then return "off" end
  end
  return "none"
end

function Q:FromQuestie(ids)
  local qdb = questieDB()
  if not qdb then return end
  self.questie = self.questie or {}
  local function ask(id, field)
    local ok, v = pcall(qdb.QueryQuestSingle, id, field)
    return ok and v or nil
  end
  for id in pairs(ids) do
    -- Forward along the chain, and one step back.
    local cur, n = id, 0
    while cur and n < 30 do
      local nxt = tonumber(ask(cur, "nextQuestInChain"))
      if not nxt or nxt == 0 or self.questie[cur] then break end
      self.questie[cur] = nxt
      cur, n = nxt, n + 1
    end
    local pre = ask(id, "preQuestSingle")
    local prev = type(pre) == "table" and tonumber(pre[1]) or tonumber(pre)
    if prev and prev ~= 0 and not self.questie[prev] then self.questie[prev] = id end
  end
end

---------------------------------------------------------------------------
-- My quest log
---------------------------------------------------------------------------
-- Objectives of a quest: have, goal, kill quest, first objective without its count.
local function objectives(questID, index, complete)
  local list = {}
  if C_QuestLog and C_QuestLog.GetQuestObjectives then
    list = C_QuestLog.GetQuestObjectives(questID) or {}
  elseif GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
    for j = 1, GetNumQuestLeaderBoards(index) or 0 do
      local text, kind, finished = GetQuestLogLeaderBoard(j, index)
      local have, need = (text or ""):match("(%d+)%s*/%s*(%d+)")
      list[#list + 1] = { text = text, type = kind, finished = finished, numFulfilled = tonumber(have) or (finished and 1 or 0), numRequired = tonumber(need) or 1 }
    end
  end
  local have, goal, kill, obj = 0, 0, false, nil
  for _, o in ipairs(list) do
    have, goal = have + (o.numFulfilled or 0), goal + (o.numRequired or 0)
    if o.type == "monster" then kill = true end
    obj = obj or (o.text and o.text:gsub("^%s*%d+%s*/%s*%d+%s*", ""):gsub("[:%s]*%d+%s*/%s*%d+%s*$", ""))
  end
  if goal == 0 then goal, have = 1, complete and 1 or 0 end
  if complete then have = goal end
  return math.min(have, goal), goal, kill, obj
end

function Q:MyLog()
  local out, zone = {}, nil
  local function add(questID, title, level, index, complete)
    if not questID or not title then return end
    local h, g, k, o = objectives(questID, index, complete)
    out[questID] = { t = title, z = zone or "", l = level or 0, h = h, g = g, k = k or nil, o = o }
  end
  if C_QuestLog and C_QuestLog.GetInfo and C_QuestLog.GetNumQuestLogEntries then
    for i = 1, C_QuestLog.GetNumQuestLogEntries() or 0 do
      local info = C_QuestLog.GetInfo(i)
      if info and info.isHeader then zone = info.title
      elseif info and not info.isHidden and not info.isTask then
        add(info.questID, info.title, info.level, i, C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID))
      end
    end
  elseif GetNumQuestLogEntries and GetQuestLogTitle then
    for i = 1, GetNumQuestLogEntries() or 0 do
      local title, level, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
      if isHeader then zone = title else add(questID, title, level, i, isComplete == 1 or isComplete == true) end
    end
  end
  -- Remember titles and zones: chain parts are shown by name once a Hero has had them.
  local d = db()
  for id, q in pairs(out) do d.questTitles[id] = q.t; if q.z ~= "" then d.questZones[id] = q.z end end
  -- Chains the game or Questie know for these quests.
  self:FromQuestLines(out)
  self:FromQuestie(out)
  self.last = out
  return out
end

local function done(id)
  local fn = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted or IsQuestFlaggedCompleted
  return fn ~= nil and fn(id) == true
end

-- Quests I have handed in, of known chains and of our own lists (attunements and dungeon quests, Data/QuestLists.lua).
function Q:MyDone()
  local out, seen = {}, {}
  local function check(id)
    if not seen[id] then seen[id] = true; if done(id) then out[#out + 1] = id end end
  end
  local links = self:Links()
  for a, b in pairs(links) do check(a); check(b) end
  for _, id in ipairs(ns.QuestLists and ns.QuestLists:AllIDs() or {}) do check(id) end
  -- And the quests of the journey's milestones.
  for _, id in ipairs(ns.Milestones:QuestIDs(F:Current())) do check(id) end
  table.sort(out)
  return out
end

-- Learned chain links that touch my quests or the ones I have done: { { from, to, fromTitle, toTitle } }. Only
-- what this account learned (the shipped chains every Companion has; Questie's are never sent).
function Q:MyLinks(log, doneList)
  local mine = {}
  for id in pairs(log) do mine[id] = true end
  for _, id in ipairs(doneList) do mine[id] = true end
  local d, out = db(), {}
  local function add(a, b)
    if (mine[a] or mine[b]) and #out < 60 then out[#out + 1] = { a, b, d.questTitles[a], d.questTitles[b] } end
  end
  for a, b in pairs(d.questLinks) do add(a, b) end
  for a, list in pairs(d.questAlts) do for _, b in ipairs(list) do add(a, b) end end
  return out
end

---------------------------------------------------------------------------
-- Stored per Hero: f.heroes[name].quests, .questsDone, .questsTime
---------------------------------------------------------------------------
local function clean(log)
  local out = {}
  if type(log) ~= "table" then return out end
  for id, q in pairs(log) do
    id = tonumber(id)
    if id and type(q) == "table" and type(q.t) == "string" then
      out[id] = { t = q.t, z = type(q.z) == "string" and q.z or "", l = tonumber(q.l) or 0, h = tonumber(q.h) or 0,
        g = math.max(1, tonumber(q.g) or 1), k = q.k == true or nil, o = type(q.o) == "string" and q.o or nil }
    end
  end
  return out
end

function Q:Store(f, name, d, t)
  if not f.members[name] then return end
  f.heroes = f.heroes or {}
  local h = f.heroes[name] or {}
  f.heroes[name] = h
  h.quests, h.questsTime = clean(d.q), tonumber(t) or time()
  h.questsDone = {}
  for _, id in ipairs(type(d.d) == "table" and d.d or {}) do if tonumber(id) then h.questsDone[tonumber(id)] = true end end
  -- Keys and attunement items this Hero carries (item IDs).
  h.keys = {}
  for _, id in ipairs(type(d.k) == "table" and d.k or {}) do if tonumber(id) then h.keys[tonumber(id)] = true end end
  local links = db()
  for _, ln in ipairs(type(d.ln) == "table" and d.ln or {}) do
    local a, b = tonumber(ln[1]), tonumber(ln[2])
    if a and b and a ~= b then
      Q:AddLink(a, b)
      if type(ln[3]) == "string" then links.questTitles[a] = links.questTitles[a] or ln[3] end
      if type(ln[4]) == "string" then links.questTitles[b] = links.questTitles[b] or ln[4] end
    end
  end
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------
-- Sends my quests to every other Hero (or one), only when they changed unless force.
function Q:Send(to, force)
  local f = F:Current()
  if not f then return end
  local log = self:MyLog()
  local doneList = self:MyDone()
  local keys = ns.QuestLists and ns.QuestLists:MyKeys() or {}
  local data = { fid = f.id, q = log, d = doneList, ln = self:MyLinks(log, doneList), k = keys, t = time() }
  local key = ns.Serialize.Encode({ log, doneList, keys })
  self:Store(f, ns.Me(), data, data.t)
  if not to and not force and key == self.lastKey then return end
  if not to then self.lastKey = key end
  local me = ns.Me()
  for name in pairs(f.members) do
    if name ~= me and (not to or name == to) then Comm:Send(name, "QUESTS", data) end
  end
  ns:Fire("HEROES")
end

Comm:On("QUESTS", function(sender, d)
  if type(d) ~= "table" then return end
  local f = F:Get(d.fid)
  if not f or not f.members[sender] or not f.members[ns.Me()] then return end
  Q:Store(f, sender, d, d.t)
  ns:Fire("HEROES")
end)

---------------------------------------------------------------------------
-- Chains and the list of shared quests
---------------------------------------------------------------------------
-- Known chains: { { ids = { questID, ... } } }, each at least two parts, from the first part to the last.
function Q:Chains()
  local links, isTo = self:Links(), {}
  for _, b in pairs(links) do isTo[b] = true end
  local chains = {}
  -- Quests with the same title one after another are one step: the class and race variants of a quest, which the
  -- game's quest lines list in a row ("Beating Them Back!" became nine parts of a 30-part chain; seen in the tour).
  -- The step keeps its first id; the others are its variants (self.variants), found by ChainAt.
  self.variants = {}
  for a in pairs(links) do
    if not isTo[a] then
      local ids, seen, id, prevTitle = {}, {}, a, nil
      while id and not seen[id] and #ids < 30 do
        seen[id] = true
        local t = knownTitle(id)
        if t and t == prevTitle then
          local step = ids[#ids]
          self.variants[step] = self.variants[step] or {}
          table.insert(self.variants[step], id)
        else
          ids[#ids + 1] = id
        end
        prevTitle = t
        id = links[id]
      end
      if #ids >= 2 then chains[#chains + 1] = { ids = ids } end
    end
  end
  table.sort(chains, function(x, y) return x.ids[1] < y.ids[1] end)
  return chains
end

-- Where a Hero is in a chain: the part (0-based) in their log, the part after the last one they handed in, or nil.
-- A branch (another next quest) counts as the step it replaces.
function Q:ChainAt(h, ids)
  if not h then return nil end
  local _, alts = self:Links()
  local function has(set, i)
    if not set then return false end
    if set[ids[i]] then return true end
    for _, b in ipairs(i > 1 and alts[ids[i - 1]] or {}) do if set[b] then return true end end
    for _, b in ipairs(self.variants and self.variants[ids[i]] or {}) do if set[b] then return true end end
    return false
  end
  for i = 1, #ids do if has(h.quests, i) then return i - 1 end end
  for i = #ids, 1, -1 do if has(h.questsDone, i) then return i end end
  return nil
end

local function title(id, h)
  return (h and h.quests and h.quests[id] and h.quests[id].t) or knownTitle(id) or ("#" .. id)
end

-- Quests to pick for a milestone (Journey Admin, M25): every quest in your log and in the logs the other Adventurers
-- share, by name. { { id, name, mine, others = { names } } }: yours first, then by name.
function Q:Pickable(f)
  local me, by, list = ns.Me(), {}, {}
  for name in pairs(f.members) do
    local h = f.heroes and f.heroes[name]
    for id, q in pairs(h and h.quests or {}) do
      local x = by[id]
      if not x then
        x = { id = id, name = q.t or knownTitle(id) or ("#" .. id), mine = false, others = {} }
        by[id] = x
        list[#list + 1] = x
      end
      if name == me then x.mine, x.name = true, q.t or x.name else x.others[#x.others + 1] = name end
    end
  end
  for _, x in ipairs(list) do table.sort(x.others) end
  table.sort(list, function(a, b)
    if a.mine ~= b.mine then return a.mine end
    if a.name ~= b.name then return a.name < b.name end
    return a.id < b.id
  end)
  return list
end

-- Every quest and chain the fellowship has (the mockup's qItems): chains first, each item
-- { id, chain, name, zone, mine, others = { names }, at / have, steps / goal, level, obj, kill }.
function Q:Items(f)
  local me = ns.Me()
  local heroes = {}
  for name in pairs(f.members) do heroes[name] = f.heroes and f.heroes[name] or nil end
  local items, inChain = {}, {}
  for _, c in ipairs(self:Chains()) do
    local at, steps = {}, {}
    for i, id in ipairs(c.ids) do inChain[id] = true; steps[i] = title(id, heroes[me]) end
    for name, h in pairs(heroes) do at[name] = self:ChainAt(h, c.ids) end
    if next(at) then
      local others = {}
      for name in pairs(at) do if name ~= me then others[#others + 1] = name end end
      table.sort(others)
      local zone = db().questZones[c.ids[1]] or ""
      items[#items + 1] = { id = "c:" .. c.ids[1], chain = true, ids = c.ids, name = steps[1], zone = zone, steps = steps, at = at,
        mine = at[me] ~= nil, others = others }
    end
  end
  local singles = {}
  for name, h in pairs(heroes) do
    for id, q in pairs(h.quests or {}) do
      if not inChain[id] then
        local s = singles[id] or { id = "q:" .. id, chain = false, name = q.t, zone = q.z, level = q.l, goal = q.g,
          obj = q.o or q.t, kill = q.k == true, have = {} }
        s.have[name] = q.h
        if name == me then s.name, s.zone, s.level, s.goal, s.obj, s.kill = q.t, q.z, q.l, q.g, q.o or q.t, q.k == true end
        singles[id] = s
      end
    end
  end
  local list = {}
  for _, s in pairs(singles) do
    s.mine = s.have[me] ~= nil
    s.others = {}
    for name in pairs(s.have) do if name ~= me then s.others[#s.others + 1] = name end end
    table.sort(s.others)
    list[#list + 1] = s
  end
  table.sort(list, function(a, b) if a.zone ~= b.zone then return a.zone < b.zone end return a.name < b.name end)
  for _, s in ipairs(list) do items[#items + 1] = s end
  for _, x in ipairs(items) do self:Classify(x) end
  return items
end

-- What a quest or chain is to me (M16: the page is about playing together, not my own log):
--   together  I am on it and another Hero is too (a chain: and someone has not finished it).
--   join      another Hero is on it, I am not, I have not done it, and my level fits (from JOIN_BELOW levels under
--             the quest's level). Learned from the fellowship's logs: there is no quest database, so a quest that
--             needs an earlier one may show too (the page says so).
-- Quests only I have are neither: the game's own quest log shows those.
Q.JOIN_BELOW = 4
function Q:Classify(x)
  local others = #x.others > 0
  if x.chain then
    local open = false
    for _, v in pairs(x.at) do if v < #x.steps then open = true end end
    x.together = x.mine and others and open
    x.join = not x.mine and others and not done(x.ids[1])
  else
    local id = tonumber(tostring(x.id):match("^q:(%d+)$"))
    local lvl = UnitLevel("player") or 0
    x.together = x.mine and others
    x.join = not x.mine and others and id ~= nil and not done(id) and (not x.level or x.level == 0 or lvl >= x.level - self.JOIN_BELOW)
  end
  return x.together or x.join
end

-- Shared quests and chains in my log that others are still on (for What's next on the Overview).
function Q:SharedCounts(f)
  local singles, chains = 0, 0
  for _, x in ipairs(self:Items(f)) do
    if x.mine and #x.others > 0 then
      if x.chain then
        local open = false
        for _, n in ipairs(x.others) do if x.at[n] < #x.steps then open = true end end
        if open then chains = chains + 1 end
      elseif x.have[ns.Me()] < x.goal then singles = singles + 1 end
    end
  end
  return singles, chains
end

local function nameList(list)
  local out = {}
  for i, n in ipairs(list) do out[i] = ns.Short(n) end
  if #out <= 2 then return table.concat(out, L.AND) end
  return table.concat(out, ", ", 1, #out - 1) .. L.AND .. out[#out]
end
Q.NameList = nameList

-- The detail of an item (the mockup's qd): { title, line, type, badge, mine, youText, youPct, youCount, youGoal,
-- parts, others = { { name, text, rel, pct, goal } }, tips }. (goal: how many to collect or kill, for the pips.)
function Q:Detail(x)
  local me = ns.Me()
  local d = { title = x.name, mine = x.mine, chain = x.chain, others = {}, tips = {}, parts = {} }
  d.badge = x.mine and L.Q_IN_LOG or L.Q_NOT_IN_LOG
  if x.chain then
    local my, n = x.at[me], #x.steps
    d.line, d.type = x.zone, L.Q_CHAIN_TYPE:format(n)
    for i, st in ipairs(x.steps) do
      local heroes = {}
      for name, v in pairs(x.at) do if v == i - 1 and name ~= me then heroes[#heroes + 1] = name end end
      table.sort(heroes)
      d.parts[i] = { n = i, id = x.ids and x.ids[i], title = st, you = my == i - 1, done = my ~= nil and my > i - 1, heroes = heroes }
    end
    for _, name in ipairs(x.others) do
      local v = x.at[name]
      local rel = ""
      if v >= n then rel = L.Q_REL_FINISHED
      elseif my then
        if v == my then rel = L.Q_REL_SAME_PART
        elseif v == my - 1 then rel = L.Q_REL_ONE_BEHIND
        elseif v < my then rel = L.Q_REL_BEHIND:format(my - v)
        elseif v == my + 1 then rel = L.Q_REL_ONE_AHEAD
        else rel = L.Q_REL_AHEAD:format(v - my) end
      end
      d.others[#d.others + 1] = { name = name, text = v >= n and L.Q_FINISHED or L.Q_PART_OF:format(v + 1, n), rel = rel, pct = math.min(1, v / n) }
    end
    if my == nil then d.tips[1] = L.TIP_CHAIN_PICKUP:format(x.zone, nameList(x.others))
    elseif my >= n then
      for _, name in ipairs(x.others) do
        if x.at[name] < n then d.tips[#d.tips + 1] = L.TIP_CHAIN_HELP:format(ns.Short(name), x.steps[x.at[name] + 1]) end
      end
      d.youText = L.Q_YOU_FINISHED_CHAIN
    else
      local same, behind, ahead = {}, {}, {}
      for _, name in ipairs(x.others) do
        local v = x.at[name]
        if v == my then same[#same + 1] = name elseif v == my - 1 then behind[#behind + 1] = name elseif v > my then ahead[#ahead + 1] = name end
      end
      if #same > 0 then d.tips[#d.tips + 1] = L.TIP_CHAIN_SAME:format(x.steps[my + 1], nameList(same)) end
      for _, name in ipairs(behind) do d.tips[#d.tips + 1] = L.TIP_CHAIN_BEHIND:format(ns.Short(name), x.steps[my], x.steps[my + 1]) end
      if #ahead > 0 then d.tips[#d.tips + 1] = (#ahead == 1 and L.TIP_CHAIN_AHEAD_1 or L.TIP_CHAIN_AHEAD_N):format(nameList(ahead), x.steps[my + 1]) end
      d.youText = L.Q_YOU_ON_PART:format(my + 1, n, x.steps[my + 1])
    end
    return d
  end
  local my = x.have[me]
  d.line = L.Q_ZONE_LEVEL:format(x.zone, x.level)
  d.type = x.kill and L.Q_KILL or L.Q_COLLECT
  local what = (x.obj or ""):gsub(" slain$", "")
  for _, name in ipairs(x.others) do
    local v = x.have[name]
    local rel = v >= x.goal and L.Q_REL_FINISHED or (my == nil and "" or (v == my and L.Q_REL_SAME or (v > my and L.Q_REL_FURTHER or L.Q_REL_BEHIND_YOU)))
    d.others[#d.others + 1] = { name = name, text = v .. " / " .. x.goal, rel = rel, pct = math.min(1, v / x.goal), goal = x.goal }
  end
  if my == nil then d.tips[1] = L.TIP_Q_PICKUP:format(x.zone, nameList(x.others))
  elseif my >= x.goal then
    for _, name in ipairs(x.others) do
      if x.have[name] < x.goal then d.tips[#d.tips + 1] = L.TIP_Q_HELP:format(ns.Short(name), x.goal - x.have[name]) end
    end
  else
    local need, fin = {}, {}
    for _, name in ipairs(x.others) do if x.have[name] < x.goal then need[#need + 1] = name else fin[#fin + 1] = name end end
    if #need > 0 then d.tips[#d.tips + 1] = L.TIP_Q_TOGETHER:format(nameList(need), what) .. (x.kill and L.TIP_Q_KILL or L.TIP_Q_LOOT) end
    for _, name in ipairs(fin) do d.tips[#d.tips + 1] = L.TIP_Q_DONE_HELP:format(ns.Short(name), x.goal - my) end
  end
  if my then
    d.youText = L.Q_YOU_HAVE:format(what, my, x.goal)
    d.youPct, d.youCount, d.youGoal = math.min(1, my / x.goal), my .. " / " .. x.goal, x.goal
  end
  return d
end

---------------------------------------------------------------------------
-- Ask to group up
---------------------------------------------------------------------------
-- Asks are answered in the inbox with Join / Not now (GRPA); Join makes the asker's addon invite you.
Q.ASK_FOR = 15 * 60
Q.asks = {}

function Q:AskGroup(x)
  local f = F:Current()
  if not f or #x.others == 0 then return end
  for _, name in ipairs(x.others) do Comm:Send(name, "GRPQ", { fid = f.id, q = x.name }) end
  ns:Toast(nil, L.REQUEST_SENT, (#x.others == 1 and L.ASKED_GROUP_1 or L.ASKED_GROUP_N):format(nameList(x.others), x.name))
end

-- Open asks to me: { { from, q, t } }, oldest first.
function Q:Asks()
  local list = {}
  for from, a in pairs(self.asks) do
    if time() - a.t <= self.ASK_FOR then list[#list + 1] = { from = from, q = a.q, t = a.t } else self.asks[from] = nil end
  end
  table.sort(list, function(a, b) return a.t < b.t end)
  return list
end

function Q:Answer(from, yes)
  local f, a = F:Current(), self.asks[from]
  self.asks[from] = nil
  if f and a then Comm:Send(from, "GRPA", { fid = f.id, q = a.q, yes = yes and true or nil }, true) end
  ns:Fire("HEROES", true)
end

Comm:On("GRPQ", function(sender, d)
  local f = type(d) == "table" and F:Get(d.fid)
  if not f or f ~= F:Current() or not f.members[sender] or type(d.q) ~= "string" then return end
  Q.asks[sender] = { q = d.q, t = time() }
  ns:Toast(nil, L.GROUP_ASKED, L.GROUP_ASKED_TEXT:format(ns.Short(sender), d.q))
  ns:Print(L.GROUP_ASKED_TEXT:format(ns.Short(sender), d.q), true)
  ns:Fire("HEROES")
end)

Comm:On("GRPA", function(sender, d)
  local f = type(d) == "table" and F:Get(d.fid)
  if not f or f ~= F:Current() or not f.members[sender] or type(d.q) ~= "string" then return end
  if d.yes then
    ns:Toast(nil, L.GROUP_YES, L.GROUP_YES_TEXT:format(ns.Short(sender), d.q))
    ns.Together:Invite({ sender })
  else
    ns:Toast(nil, L.GROUP_NO, L.GROUP_NO_TEXT:format(ns.Short(sender), d.q))
  end
end)

---------------------------------------------------------------------------
-- Share quest (the game's quest sharing to my group)
---------------------------------------------------------------------------
-- The quest of an item I can share: a single quest in my log, or the part of a chain I am on.
function Q:ShareID(x)
  if not x or not x.mine then return nil end
  local id
  if x.chain then
    local at = x.at[ns.Me()]
    id = at and x.ids and x.ids[at + 1]
  else
    id = tonumber(tostring(x.id):match("^q:(%d+)$"))
  end
  if not id or not (self.last and self.last[id]) then return nil end
  return id
end

function Q:CanShare(x) return (self:ShareState(x)) == "ok" end

-- Can I share it, and if not why (M21: the button was hidden without a word)? "ok", "group" (not in a group),
-- "no" (the game does not let this quest be shared), or nil (not a quest in my log: no button at all).
function Q:ShareState(x)
  local id = self:ShareID(x)
  if not id or not QuestLogPushQuest then return nil end
  if C_QuestLog and C_QuestLog.IsPushableQuest and C_QuestLog.IsPushableQuest(id) ~= true then return "no" end
  if not (IsInGroup and IsInGroup()) then return "group" end
  return "ok"
end

function Q:Share(x)
  local id = self:ShareID(x)
  if not id or not QuestLogPushQuest then return end
  if C_QuestLog and C_QuestLog.SetSelectedQuest then C_QuestLog.SetSelectedQuest(id) end
  QuestLogPushQuest()
end

-- Invite to group: the other Heroes on this quest who are online.
function Q:InviteFor(x)
  local f = F:Current()
  if not f or not x then return end
  local list = {}
  for _, name in ipairs(x.others) do if ns.Hero:Online(f, name) then list[#list + 1] = name end end
  if #list == 0 then ns:Toast(nil, L.INVITED, L.NOBODY_ONLINE) return end
  ns.Together:Invite(list)
end

---------------------------------------------------------------------------
-- Game events: learn chain links, send my quests when they change
---------------------------------------------------------------------------
local function npcGUID()
  local g = UnitGUID("npc") or UnitGUID("questnpc")
  if g == nil or secret(g) then return nil end
  return g
end

ns:RegisterEvent("QUEST_TURNED_IN", function(_, questID)
  if tonumber(questID) then Q.turnedIn = { id = tonumber(questID), at = GetTime(), npc = npcGUID() } end
  Q:Soon()
end)

ns:RegisterEvent("QUEST_ACCEPTED", function(_, a, b)
  local id = tonumber(b) or tonumber(a) -- Classic: (log index, questID); retail: (questID)
  local t = Q.turnedIn
  local npc = npcGUID()
  if id and t and t.id ~= id and npc and t.npc == npc and GetTime() - t.at <= Q.LINK_WITHIN then
    Q:AddLink(t.id, id)
  end
  Q:Soon()
end)

-- The quest giver offers the next quest right after a hand-in: linked even if it is not accepted now (the next part
-- of a chain is often offered at once and taken later).
ns:RegisterEvent("QUEST_DETAIL", function()
  local id = GetQuestID and tonumber(GetQuestID())
  local t, npc = Q.turnedIn, npcGUID()
  if id and id ~= 0 and t and t.id ~= id and npc and t.npc == npc and GetTime() - t.at <= Q.LINK_WITHIN then
    Q:AddLink(t.id, id)
  end
end)

function Q:Soon()
  if self.timer then return end
  self.timer = C_Timer.NewTimer(self.SEND_DELAY, function() Q.timer = nil; Q:Send() end)
end

ns:RegisterEvent("QUEST_LOG_UPDATE", function() if F:Current() then Q:Soon() end end)
ns:On("JOINED", function() Q:Send(nil, true) end)
ns:On("LOGIN", function() C_Timer.After(6, function() Q:Send(nil, true) end) end)
