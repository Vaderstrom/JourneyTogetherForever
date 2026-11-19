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

local secret = ns.Secret
local NONE = {}

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
  if not cur then d.questLinks[a] = b; self:Stale() return end
  if cur == b then return end
  local alts = d.questAlts[a] or {}
  for _, x in ipairs(alts) do if x == b then return end end
  if #alts < 4 then alts[#alts + 1] = b; self:Stale() end
  d.questAlts[a] = alts
end

-- Links() and Chains() are remembered until a link, a title or Questie's links change (Q:Stale): with Questie's
-- thousands of links every look walked them all again (the owner, 15 Nov 2026: "I don't want this addon to cause any
-- stuttering"). Callers only read what they get. (A test that edits the shipped chains calls Q:Stale itself.)
Q.rev = 0
function Q:Stale() self.rev = self.rev + 1 end

-- Every chain link the addon knows, from four sources (docs/QUEST-CHAINS.md), weakest first:
--   Questie's database when the player has Questie (read at run time only: never saved, shared or harvested),
--   the chains we ship (Data/QuestChains.lua), and what this account learned (the game's quest lines included).
-- Returns links[a] = b and alts[a] = { other next quests }.
function Q:Links()
  local d, ship = db(), ns.QUEST_CHAINS or {}
  local m = self.linksMemo
  if m and m.rev == self.rev then return m.links, m.alts end
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
  self.linksMemo = { rev = self.rev, links = links, alts = alts }
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
  if ok and type(t) == "string" and not secret(t) and t ~= "" then -- (secret first: no comparing a secret value)
    local d = db()
    if d.questTitles[id] ~= t then d.questTitles[id] = t; Q:Stale() end -- (the chains go by title: walked again)
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
Q.Title = knownTitle -- (the chain before a dungeon quest, QuestLists.lua)

-- A dungeon quest's name as the game names it, else our data's (the owner, 11 Nov 2026: the game renamed 5047 and
-- 5214, and the book kept the old names).
function Q.Name(id, fallback)
  return gameTitle(id) or db().questTitles[id] or fallback
end

-- A title the game was asked for has arrived: show it.
local dungeonIDs -- (the dungeon quests' IDs, made at the first title that arrives)
ns:RegisterEvent("QUEST_DATA_LOAD_RESULT", function(_, id, ok)
  if not (ok and Q.titleAsked[id] and gameTitle(id)) then return end
  -- (The chains still waiting for a title walk again; the dungeon lists are made again with the game's names.)
  if ns.QuestLists then
    ns.QuestLists.prevAt = -math.huge
    if not dungeonIDs then
      dungeonIDs = {}
      for _, list in pairs(ns.DUNGEON_QUESTS or {}) do for _, q in ipairs(list) do dungeonIDs[q[1]] = true end end
    end
    if dungeonIDs[id] then ns.QuestLists.made = {} end
  end
  if ns.Window and ns.Window.RefreshSoon then ns.Window:RefreshSoon("quests") end
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

-- One of Questie's modules (QuestieDB, ZoneDB), nil without Questie.
function Q.QuestieModule(name)
  local loader = QuestieLoader
  if type(loader) ~= "table" or not loader.ImportModule then return nil end
  local ok, m = pcall(loader.ImportModule, loader, name)
  return ok and type(m) == "table" and m or nil
end

-- Questie (another addon, GPL) when the player has it: its next and previous quest of each quest in the log. Kept
-- for this session only (self.questie), never saved, sent or harvested, so nothing of Questie's database ends up in
-- this addon or its data (which stay MIT).
-- Asked again until found: Questie may load after this addon.
local function questieDB()
  if Q.qdb then return Q.qdb end
  local m = Q.QuestieModule("QuestieDB")
  if m and m.QueryQuestSingle then Q.qdb = m; Q:Stale() end -- (its names join the chains' titles)
  return Q.qdb
end
Q.QuestieDB = questieDB

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
      self:Stale()
    end
    local pre = ask(id, "preQuestSingle")
    local prev = type(pre) == "table" and tonumber(pre[1]) or tonumber(pre)
    if prev and prev ~= 0 and not self.questie[prev] then self.questie[prev] = id; self:Stale() end
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
  for id, q in pairs(out) do
    if d.questTitles[id] ~= q.t then d.questTitles[id] = q.t; self:Stale() end
    if q.z ~= "" then d.questZones[id] = q.z end
  end
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
  -- (Our lists, the dungeon quests and their chains' steps: QuestLists:AllIDs.)
  for _, id in ipairs(ns.QuestLists and ns.QuestLists:AllIDs() or {}) do check(id) end
  -- And the quests of the journey's milestones.
  local f = F:Current()
  for _, id in ipairs(ns.Milestones:QuestIDs(f)) do check(id) end
  -- And every quest in the other Adventurers' logs (U265): They could join you leaves out what I have done.
  for name in pairs(f and f.members or NONE) do
    local h = name ~= ns.Me() and f.heroes and f.heroes[name]
    for id in pairs(h and h.quests or NONE) do check(id) end
  end
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

-- True when two sets hold the same keys (only the keys `only` accepts, when given).
local function sameSet(a, b, only)
  for k in pairs(a or {}) do if not (b and b[k]) and (not only or only(k)) then return false end end
  for k in pairs(b or {}) do if not (a and a[k]) and (not only or only(k)) then return false end end
  return true
end
local function isDungeonQuest(id) return ns.QuestLists:IsDungeonQuest(id) end

function Q:Store(f, name, d, t)
  if not f.members[name] then return end
  f.heroes = f.heroes or {}
  local h = f.heroes[name] or {}
  f.heroes[name] = h
  -- (A log from an older addon has no time: none is made up from this clock, so a log its owner sent later, passed on
  -- by someone else, still wins over it, and it is never passed on as newer than one that has a time; code review of
  -- 0.13.0.)
  local wasDone, wasKeys, wasLog = h.questsDone, h.keys, h.quests
  h.quests, h.questsTime = clean(d.q), tonumber(t)
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
      if type(ln[3]) == "string" and not links.questTitles[a] then links.questTitles[a] = ln[3]; Q:Stale() end
      if type(ln[4]) == "string" and not links.questTitles[b] then links.questTitles[b] = ln[4]; Q:Stale() end
    end
  end
  -- True when the quests handed in or the keys changed (milestones, attunements), or a dungeon quest was picked up or
  -- dropped (the room for the dungeon quests on the Overview counts one in your log at the game's XP; picking one up
  -- left that card as it was: code review of 1.2.0): more than the quest pages show.
  return not (sameSet(wasDone, h.questsDone) and sameSet(wasKeys, h.keys) and sameSet(wasLog, h.quests, isDungeonQuest))
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------
-- Sends my quests to every other Hero (or one), only when they changed unless force.
-- Only the newest list waits for each Hero (replace), and the chain links go only when they changed or to one Hero
-- (a login, a newcomer): the ponytail audit of 6 Nov 2026 measured a list at about 9 KB, half of it links, sent to
-- every Hero every 15 seconds while questing; with five Adventurers that is all the bytes the game lets an addon send,
-- and the lists piled up (in a dungeon, one more each time a quest moved), with every change waiting behind them.
function Q:Send(to, force)
  local f = F:Current()
  if not f then return end
  local log = self:MyLog()
  local doneList = self:MyDone()
  local keys = ns.QuestLists and ns.QuestLists:MyKeys() or {}
  local links = self:MyLinks(log, doneList)
  local data = { fid = f.id, q = log, d = doneList, ln = links, k = keys, t = time() }
  local key = ns.Serialize.Encode({ log, doneList, keys })
  local doneMoved = self:Store(f, ns.Me(), data, data.t)
  local mine = f.heroes and f.heroes[ns.Me()]
  self.sentDone = mine and mine.questsDone -- (what the others have heard I did, U265)
  if not to and not force and key == self.lastKey then return end
  if not to then self.lastKey = key end
  local lkey = ns.Serialize.Encode(links)
  local same = not to and not force and lkey == self.lastLinks
  if not to then self.lastLinks = lkey end
  local short
  if same then
    short = {}
    for k, v in pairs(data) do if k ~= "ln" then short[k] = v end end
  end
  -- Packed once for all who get the whole list and once for those who get it without links (U71); none for those
  -- the game said are offline (U76: their HELLO brings it). (A list still waiting for them may carry links they have
  -- not had yet: the newer one takes them over.)
  local whole, brief = {}, {}
  for _, name in ipairs(to and (f.members[to] and to ~= ns.Me() and { to } or {}) or ns.Hero:Reachable(f)) do
    local list = (short and not Comm:Waiting(name, "QUESTS")) and brief or whole
    list[#list + 1] = name
  end
  if #whole > 0 then Comm:SendAll(whole, "QUESTS", data, false, true) end
  if #brief > 0 then Comm:SendAll(brief, "QUESTS", short, false, true) end
  -- A quest list redraws only the pages that show quest logs (U74); a milestone, attunement or dungeon quest, every page.
  ns:Fire("HEROES", nil, not doneMoved and "quests" or nil)
end

-- A Hero's stored quests as QUESTS sends them, to pass on (Hero:Relay, RELAYQ).
function Q:Stored(h)
  local ids, keys = {}, {}
  for id in pairs(h.questsDone or {}) do ids[#ids + 1] = id end
  for id in pairs(h.keys or {}) do keys[#keys + 1] = id end
  table.sort(ids); table.sort(keys)
  return { q = h.quests, d = ids, k = keys, t = h.questsTime }
end

Comm:On("QUESTS", function(sender, d)
  if type(d) ~= "table" then return end
  local f = F:Get(d.fid)
  if not f or not f.members[sender] or not f.members[ns.Me()] then return end
  local doneMoved = Q:Store(f, sender, d, d.t)
  ns:Fire("HEROES", nil, not doneMoved and "quests" or nil)
  -- A quest in their log that I have done and not yet said so (U265): my list goes again, once (Q:Soon waits, and
  -- the next list says it).
  local said = Q.sentDone
  if said then
    for id in pairs(f.heroes[sender].quests or NONE) do
      if not said[id] and done(id) then Q:Soon() break end
    end
  end
end)

---------------------------------------------------------------------------
-- Chains and the list of shared quests
---------------------------------------------------------------------------
-- Known chains: { { ids = { questID, ... } } }, each at least two parts, from the first part to the last. Also
-- index[questID] = the chains (their numbers here) it is a step of, as ChainAt finds it (a variant, or a branch of
-- the step before), and all[questID] = true for every step.
function Q:Chains()
  local m = self.chainsMemo
  if m and m.rev == self.rev then self.variants = m.variants; return m.chains, m.index, m.all end
  local links, alts = self:Links()
  local isTo = {}
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
  local index, all = {}, {}
  local function add(id, k) local t = index[id] or {}; index[id] = t; t[#t + 1] = k end
  for k, c in ipairs(chains) do
    for i, id in ipairs(c.ids) do
      all[id] = true
      add(id, k)
      for _, v in ipairs(self.variants[id] or {}) do add(v, k) end
      for _, b in ipairs(i > 1 and alts[c.ids[i - 1]] or {}) do add(b, k) end
    end
  end
  self.chainsMemo = { rev = self.rev, chains = chains, variants = self.variants, index = index, all = all }
  return chains, index, all
end

-- Where a Hero is in a chain: the part (0-based) in their log, the part after the last one they handed in, or nil.
-- A branch (another next quest) counts as the step it replaces. alts: Links()'s branches, from a caller that asks
-- for many (each Links() copies every link: once per chain and Adventurer, it made "script ran too long" on the
-- tracker, the owner's BugGrabber of 15 Nov 2026).
-- (No table or function made per look: it runs for every chain and Adventurer, 778 KB of throwaway data a list.)
local function has(variants, set, ids, i, alts)
  if not set then return false end
  if set[ids[i]] then return true end
  for _, b in ipairs(i > 1 and alts[ids[i - 1]] or NONE) do if set[b] then return true end end
  for _, b in ipairs(variants and variants[ids[i]] or NONE) do if set[b] then return true end end
  return false
end
function Q:ChainAt(h, ids, alts)
  if not h then return nil end
  if not alts then alts = select(2, self:Links()) end
  local v = self.variants
  for i = 1, #ids do if has(v, h.quests, ids, i, alts) then return i - 1 end end
  for i = #ids, 1, -1 do if has(v, h.questsDone, ids, i, alts) then return i end end
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
  -- Not the Fallen: their journey ended (as on Play now, Together.lua), so no list here names them: to do together,
  -- could join, Ask to group up, the maps (the release review of 20 Nov 2026).
  for name in pairs(f.members) do
    if name == me or not ns.Challenges:Fallen(f, name) then heroes[name] = f.heroes and f.heroes[name] or nil end
  end
  local items = {}
  local _, alts = self:Links()
  local chains, index, inChain = self:Chains()
  -- Only the chains someone here has a step of, in the log or handed in (ChainAt is nil for all others): with
  -- Questie's thousands, every chain for every Adventurer was about 40 ms a look.
  local on, ks = {}, {}
  local function mark(set)
    for id in pairs(set or NONE) do
      for _, k in ipairs(index[id] or NONE) do if not on[k] then on[k] = true; ks[#ks + 1] = k end end
    end
  end
  for _, h in pairs(heroes) do mark(h.quests); mark(h.questsDone) end
  table.sort(ks)
  for _, k in ipairs(ks) do
    local c = chains[k]
    local at, steps = {}, {}
    for i, id in ipairs(c.ids) do steps[i] = title(id, heroes[me]) end
    for name, h in pairs(heroes) do at[name] = self:ChainAt(h, c.ids, alts) end
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
  for _, x in ipairs(items) do
    x.joiners = x.mine and not Q.Finished(x, me) and self:Joiners(f, x, heroes) or {}
    self:Classify(x)
  end
  return items
end

-- What a quest or chain is to me (M16: the page is about playing together, not my own log):
--   together  I am on it and another Hero is too (a chain: and someone has not finished it).
--   join      another Hero is on it, I am not, I have not done it, and my level fits (from JOIN_BELOW levels under
--             the quest's level). Learned from the fellowship's logs: there is no quest database, so a quest that
--             needs an earlier one may show too (the page says so).
--   bring     neither, and another Adventurer could join me (x.joiners: mine and not finished; U264).
-- Quests only I have, with nobody to join me, are none of these: the game's own quest log shows those.
Q.JOIN_BELOW = 4
Q.GREY_BELOW = 5 -- (a quest this many levels under you is grey: the Together tab, and who could join you)
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
    -- A dungeon's quest is done in the run (U110): Play now and the tracker never suggest it to quest together.
    x.dungeon = id ~= nil and ns.QuestLists:IsDungeonQuest(id)
    x.together = x.mine and others
    x.join = not x.mine and others and id ~= nil and not done(id) and (not x.level or x.level == 0 or lvl >= x.level - self.JOIN_BELOW)
  end
  x.bring = not x.together and #(x.joiners or NONE) > 0
  return x.together or x.join or x.bring
end

-- A single quest's ID (its item id "q:123"), or nil for a chain.
function Q.QuestID(x) return tonumber(tostring(x.id):match("^q:(%d+)$")) end

-- Names in order: you first, then by name.
function Q.MeFirst(a, b)
  local me = ns.Me()
  if (a == me) ~= (b == me) then return a == me end
  return a < b
end

-- Who could join me on x, a quest or chain in my log (U264): another Adventurer not on it, who has not done it (by
-- what their addon shares, U265; an older addon shares nothing, so its Adventurer is judged by level alone), and whose
-- level is from JOIN_BELOW under the quest's level to GREY_BELOW over it (a chain: its first step's, where they start;
-- unknown: any level). Online or not. heroes: Items' (name -> stored Hero), Adventurers never heard from left out.
function Q:Joiners(f, x, heroes)
  local me, out = ns.Me(), {}
  local first = x.chain and x.ids[1] or Q.QuestID(x)
  local lvl = x.level
  if x.chain then
    for _, h in pairs(heroes) do
      local q = h.quests and h.quests[first]
      if q and (q.l or 0) > 0 then lvl = q.l end
    end
  end
  for name, h in pairs(heroes) do
    local on = x.chain and x.at[name] ~= nil or (not x.chain and x.have[name] ~= nil)
    if name ~= me and not on and not (first and h.questsDone and h.questsDone[first]) then
      local their = ns.Hero:Level(f, name)
      if not lvl or lvl == 0 or (their >= lvl - self.JOIN_BELOW and their <= lvl + self.GREY_BELOW) then
        out[#out + 1] = name
      end
    end
  end
  table.sort(out)
  return out
end

-- One face (U263, UI.Faces): { name, class (token), online, here (online in zone), faded, tip }. zone: the quest's.
function Q:Face(f, name, zone, faded)
  local Hr, me = ns.Hero, ns.Me()
  local h = f.heroes and f.heroes[name]
  local online = name == me or Hr:Online(f, name)
  local at = h and type(h.zone) == "string" and h.zone ~= "" and not secret(h.zone) and h.zone or nil
  local tip
  if faded then tip = L.FACE_COULD:format(ns.Short(name))
  elseif name == me then tip = L.YOU_LABEL
  elseif online then tip = at and L.FACE_ONLINE:format(ns.Short(name), at) or L.FACE_ONLINE_ANY:format(ns.Short(name))
  else tip = L.FACE_OFFLINE:format(ns.Short(name), ns.TimeAgo(Hr:LastSeen(f, name))) end
  return { name = name, class = select(2, Hr:ClassName(f, name)), online = online, faded = faded, tip = tip,
    here = online and at ~= nil and type(zone) == "string" and zone ~= "" and at:lower() == zone:lower() }
end

-- The faces of a row: who has it, then faded who could join me.
function Q:Faces(f, x)
  local out = {}
  for _, name in ipairs(x.others) do out[#out + 1] = self:Face(f, name, x.zone) end
  for _, name in ipairs(x.joiners or NONE) do out[#out + 1] = self:Face(f, name, x.zone, true) end
  return out
end

-- Finished by me (U188, the owner, 12 Nov 2026): a chain I have done to its last part, or a quest in my log with every
-- objective met. The Quests page keeps them under History.
function Q.Finished(x, me)
  if not x.mine then return false end
  if x.chain then return (x.at[me] or 0) >= #x.steps end
  return x.goal ~= nil and (x.have[me] or 0) >= x.goal
end

-- Where I am, for sorting quests by how close they are (the owner, 6 Nov 2026: "a better way to divide between zones
-- and close by"). here: the names of the zone and subzone I am in; near: every map on my continent (the game's map
-- tree, from my map up to its continent). Quest log headers name a quest's zone, so names are compared, in lower case.
local CONTINENT = 2 -- Enum.UIMapType.Continent
Q.continentMaps = {}
function Q:Whereabouts()
  local here, near = {}, {}
  local function add(set, name) if type(name) == "string" and name ~= "" and not secret(name) then set[name:lower()] = true end end
  add(here, GetRealZoneText and GetRealZoneText()); add(here, GetZoneText and GetZoneText())
  add(here, GetSubZoneText and GetSubZoneText())
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local info = map and C_Map.GetMapInfo(map)
  if info then add(here, info.name) end
  local guard = 0
  while info and (info.mapType or 0) > CONTINENT and (info.parentMapID or 0) > 0 and guard < 8 do
    info, guard = C_Map.GetMapInfo(info.parentMapID), guard + 1
  end
  if info and info.mapType == CONTINENT and C_Map.GetMapChildrenInfo then
    local names = self.continentMaps[info.mapID]
    if not names then
      names = {}
      for _, child in ipairs(C_Map.GetMapChildrenInfo(info.mapID, nil, true) or {}) do add(names, child.name) end
      self.continentMaps[info.mapID] = names
    end
    near = names
  end
  return { here = here, near = near }
end

-- How close a quest's zone is: "here" (I am in it), "near" (on my continent) or nil. w: Whereabouts(), once per list.
function Q:Nearness(zone, w)
  if type(zone) ~= "string" or zone == "" then return nil end
  w = w or self:Whereabouts()
  local z = zone:lower()
  if w.here[z] then return "here" end
  if w.near[z] then return "near" end
  return nil
end

-- The others on a quest who are online in its zone now (from their last state; Fellowship/Hero.lua sends the zone).
function Q:ThereNow(f, x)
  local out = {}
  if type(x.zone) ~= "string" or x.zone == "" then return out end
  for _, name in ipairs(x.others) do
    local h = f.heroes and f.heroes[name]
    if h and type(h.zone) == "string" and h.zone:lower() == x.zone:lower() and ns.Hero:Online(f, name) then out[#out + 1] = name end
  end
  return out
end

local function nameList(list)
  local out = {}
  for i, n in ipairs(list) do out[i] = ns.Short(n) end
  if #out <= 2 then return table.concat(out, L.AND) end
  return table.concat(out, ", ", 1, #out - 1) .. L.AND .. out[#out]
end
Q.NameList = nameList

-- The detail of an item (SPEC §4.6, U264, the owner's grilling of 19 Nov 2026: the answer first): { title, line, type,
-- mine, chain, tips (the answer, a line each, at most ANSWER_MAX), rows (a quest: where everyone stands, you first:
-- { name, have, goal }), steps (a chain's track: { n, id, title, you, done, on = { names on that step, you first },
-- could = { who could join you, on step 1 } }) }. Each fact once (U189): no "same part as you", no Other Adventurers
-- for a chain, no What you can do list.
Q.ANSWER_MAX = 5
function Q:Detail(x)
  local me = ns.Me()
  local d = { title = x.name, mine = x.mine, chain = x.chain, tips = {}, rows = {}, steps = {} }
  local tips, joiners = d.tips, x.joiners or NONE
  local function first(list) table.sort(list, Q.MeFirst) return list end
  if x.chain then
    local my, n = x.at[me], #x.steps
    d.line, d.type = x.zone, L.Q_CHAIN_TYPE:format(n)
    for i, st in ipairs(x.steps) do
      local on = {}
      for name, v in pairs(x.at) do if v == i - 1 then on[#on + 1] = name end end
      d.steps[i] = { n = i, id = x.ids and x.ids[i], title = st, you = my == i - 1, done = my ~= nil and my > i - 1,
        on = first(on), could = i == 1 and joiners or NONE }
    end
    -- By how far apart, your step counting as the first when you are not on it.
    if my == nil then
      tips[1] = x.zone ~= "" and L.Q_ANS_PICKUP:format(x.zone, x.steps[1]) or L.Q_ANS_PICKUP_HERE:format(x.steps[1])
    end
    if my and my >= n then
      for _, name in ipairs(x.others) do
        local v = x.at[name]
        if v < n then tips[#tips + 1] = L.Q_ANS_DONE_HELP:format(ns.Short(name), v + 1, x.steps[v + 1]) end
      end
    else
      local mine, same = my or 0, {}
      for _, name in ipairs(x.others) do if math.min(x.at[name], n) == mine then same[#same + 1] = name end end
      if #same > 0 then tips[#tips + 1] = L.Q_ANS_SAME:format(nameList(same), x.steps[mine + 1]) end
      for _, name in ipairs(x.others) do
        local v = math.min(x.at[name], n)
        local gap, who = mine - v, ns.Short(name)
        if gap == 1 then tips[#tips + 1] = L.Q_ANS_BEHIND_1:format(who, x.steps[v + 1])
        elseif gap > 1 then tips[#tips + 1] = L.Q_ANS_BEHIND_N:format(who, gap, mine + 1, v + 1, mine)
        elseif gap == -1 then tips[#tips + 1] = L.Q_ANS_AHEAD_1:format(who, x.steps[mine + 1])
        elseif gap < -1 then tips[#tips + 1] = L.Q_ANS_AHEAD_N:format(who, -gap, mine + 1, v) end
      end
      if #joiners > 0 then
        tips[#tips + 1] = (mine == 0 and L.Q_ANS_START_WITH or L.Q_ANS_START_CATCH):format(nameList(joiners), x.steps[1])
      end
    end
  else
    local my = x.have[me]
    d.line = L.Q_ZONE_LEVEL:format(x.zone, x.level)
    d.type = x.kill and L.Q_KILL or L.Q_COLLECT
    -- Where everyone stands: you first, then the others.
    local names = {}
    for name in pairs(x.have) do names[#names + 1] = name end
    for _, name in ipairs(first(names)) do d.rows[#d.rows + 1] = { name = name, have = x.have[name], goal = x.goal } end
    if my == nil then
      tips[1] = x.zone ~= "" and L.TIP_Q_PICKUP:format(x.zone, nameList(x.others)) or L.TIP_Q_PICKUP_HERE:format(nameList(x.others))
    elseif my >= x.goal then
      for _, name in ipairs(x.others) do
        if x.have[name] < x.goal then tips[#tips + 1] = L.Q_ANS_Q_HELP:format(ns.Short(name), x.goal - x.have[name]) end
      end
    else
      local need, fin = {}, {}
      for _, name in ipairs(x.others) do if x.have[name] < x.goal then need[#need + 1] = name else fin[#fin + 1] = name end end
      if #need > 0 then tips[#tips + 1] = (x.kill and L.Q_ANS_Q_KILL or L.Q_ANS_Q_LOOT):format(nameList(need)) end
      for _, name in ipairs(fin) do tips[#tips + 1] = L.Q_ANS_Q_DONE_HELP:format(ns.Short(name), x.goal - my) end
    end
    if #joiners > 0 then
      tips[#tips + 1] = x.zone ~= "" and L.Q_ANS_BRING:format(nameList(joiners), x.zone) or L.Q_ANS_BRING_HERE:format(nameList(joiners))
    end
  end
  for i = #tips, self.ANSWER_MAX + 1, -1 do tips[i] = nil end
  return d
end

-- A quest giver's spot from Questie while it runs (U267): { x, y (0-100), map, by } or nil. Read for this session only,
-- never kept (as FromQuestie). shortcut: the first spawn of the first NPC that starts it; objects and items give none.
function Q:QuestiePlace(id)
  local qdb, zdb = questieDB(), Q.QuestieModule("ZoneDB")
  if not (qdb and qdb.QueryNPCSingle and zdb and zdb.GetUiMapIdByAreaId) then return nil end
  local ok, by = pcall(qdb.QueryQuestSingle, id, "startedBy")
  local npc = ok and type(by) == "table" and type(by[1]) == "table" and tonumber(by[1][1])
  if not npc then return nil end
  local ok2, spawns = pcall(qdb.QueryNPCSingle, npc, "spawns")
  local ok3, name = pcall(qdb.QueryNPCSingle, npc, "name")
  for area, list in pairs(ok2 and type(spawns) == "table" and spawns or NONE) do
    local pt = type(list) == "table" and list[1]
    local okm, map = pcall(zdb.GetUiMapIdByAreaId, zdb, area)
    if type(pt) == "table" and tonumber(pt[1]) and tonumber(pt[2]) and okm and tonumber(map) then
      return { x = tonumber(pt[1]), y = tonumber(pt[2]), map = tonumber(map), by = ok3 and type(name) == "string" and name or nil }
    end
  end
  return nil
end

-- The in-book map of a quest or chain (U267): the zone of my next step (step 1's when I am not on it) and its places
-- as QuestLists:Marks entries: in my log, where the game marks it on the map; else where it is picked up (a dungeon
-- quest's from our data, any quest's giver while Questie runs). { map, marks, target ({ st, map }), who (the
-- Adventurers on it, you too) }, or nil without a map for the zone.
function Q:MapPlan(x)
  local QL, me = ns.QuestLists, ns.Me()
  local id, name, zone
  if x.chain then
    local k = math.min((x.at[me] or 0) + 1, #x.ids)
    id, name, zone = x.ids[k], x.steps[k], db().questZones[x.ids[k]] or x.zone
  else
    id, name, zone = Q.QuestID(x), x.name, x.zone
  end
  local map = type(zone) == "string" and zone ~= "" and QL:MapOf({ zone = zone }) or nil
  -- A subzone the log files it under (Shadowglen has no map of its own; the check of 19 Nov 2026): the map you are
  -- on, while you are there.
  if not map and self:Nearness(zone) == "here" and C_Map and C_Map.GetBestMapForUnit then
    map = C_Map.GetBestMapForUnit("player")
  end
  if not map then return nil end
  local marks, item = {}, { name = name, status = "log" }
  local inLog = id and C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id) ~= nil
  if inLog and C_QuestLog.GetQuestsOnMap then
    local ok, list = pcall(C_QuestLog.GetQuestsOnMap, map)
    for _, q in ipairs(ok and type(list) == "table" and list or NONE) do
      if not (secret(q.questID) or secret(q.x) or secret(q.y)) and q.questID == id and type(q.x) == "number"
        and type(q.y) == "number" then
        marks[1] = { st = { x = q.x * 100, y = q.y * 100, zone = zone }, map = map, items = { item }, next = true }
      end
    end
  elseif id then
    local st = QL:Start(id)
    st = st and st.x and st.y and st or self:QuestiePlace(id)
    local at = st and (st.map or QL:MapOf(st))
    if at then marks[1] = { st = st, map = at, items = { item }, next = true } end
  end
  marks.focus = #marks > 0 and 1 or nil
  local who = {}
  for name2 in pairs(x.chain and x.at or x.have) do who[#who + 1] = name2 end
  table.sort(who, Q.MeFirst)
  return { map = map, marks = marks, who = who, target = marks[1] and { st = marks[1].st, map = marks[1].map } or nil }
end

---------------------------------------------------------------------------
-- Ask to group up
---------------------------------------------------------------------------
-- Asks are answered in the inbox with Join / Not now (GRPA); Join makes the asker's addon invite you.
Q.ASK_FOR = 15 * 60
Q.asks = {}

-- Who Ask to group up is for: the others on it, else those who could join you (U264). (Its button shows while this
-- has anyone.)
function Q.AskList(x) return #x.others > 0 and x.others or x.joiners or NONE end

-- Asks the online ones among the others on it, else among those who could join you (the release review of 20 Nov 2026:
-- with the others offline it said nobody was online while someone who could join was).
function Q:AskGroup(x)
  local f = F:Current()
  if not f then return end
  local function online(list)
    local out = {}
    for _, name in ipairs(list or NONE) do if ns.Hero:Online(f, name) then out[#out + 1] = name end end
    return out
  end
  local to = online(x.others)
  if #to == 0 then to = online(x.joiners) end
  if #to == 0 then ns:Toast(nil, L.ASK_GROUP, L.ASK_NOBODY_ONLINE) return end
  for _, name in ipairs(to) do Comm:Send(name, "GRPQ", { fid = f.id, q = x.name }) end
  ns:Toast(nil, L.REQUEST_SENT, (#to == 1 and L.ASKED_GROUP_1 or L.ASKED_GROUP_N):format(nameList(to), x.name))
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
  if id then self:Push(id) end
end

-- The game's quest sharing for a quest in my log (also the share reminder in a dungeon, U178).
function Q:Push(id)
  if not QuestLogPushQuest then return end
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
