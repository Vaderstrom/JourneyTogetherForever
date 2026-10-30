-- Clears and History (SPEC §1, §4.5, §4.7).
-- A dungeon is cleared for a Hero once they were in the group for every needed boss, in one run or several.
-- A boss kill counts when the dungeon is open and at least "Heroes needed for a run" Heroes are in the group.
-- Needed bosses: every boss of the dungeon, or the ones Journey Admin chose (journey.place[key].bosses).
--   f.kills[key]  = { heroName = { bossToken = time } }   which needed bosses each Hero was there for
--   f.runs[key]   = { heroName = time }                   who has cleared the dungeon
--   f.undone[key] = { ["*"] = time, heroName = time }     when clears were undone: earlier kill reports are ignored
--   f.history     = { entry, ... }, newest first. Run entries: one per dungeon visit, { key, names, killed, ... }.
-- Boss lists come from the game's own data (Data/Encounters.lua, built from wago.tools for Forever and retail),
-- else bosses learned on the kill. A boss token is "e<encounter ID>" (the ID ENCOUNTER_END gives), or "n<name>".
-- Every Hero's addon in the group records each kill at once (so toasts are immediate) and sends RUN to the other
-- Heroes (held until the group leaves the instance). RUN is not a versioned op: reports of one kill are the same
-- kill, so one missing report does not stop it. Mark cleared and Undo are ops (Fellowship.lua).
local _, ns = ...
local L = ns.L
local F, J, Comm = ns.Fellowship, ns.Journey, ns.Comm
local C = { recent = {} }
ns.Clears = C

C.HISTORY_MAX = 100
C.SAME_RUN = 7200 -- kills in one dungeon less than two hours apart are one run in the history
C.REPEAT = 300    -- the same boss again within 5 minutes is the same kill

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) end

local function dname(key) local d = ns.Dungeon(key); return d and d[2] or key end

-- "Victor, Noa, Pata and Pepsi"
local function andList(list)
  local out = {}
  for i, name in ipairs(list) do out[i] = ns.Short(name) end
  if #out <= 1 then return out[1] or "" end
  return table.concat(out, ", ", 1, #out - 1) .. L.AND .. out[#out]
end
C.AndList = andList

local function has(list, v)
  for _, x in ipairs(list) do if x == v then return true end end
  return false
end

---------------------------------------------------------------------------
-- Boss lists
---------------------------------------------------------------------------
-- The game's bosses of a dungeon (Data/Encounters.lua, for this game version): the whole instance, and the ones
-- that belong to this dungeon when it shares the instance (by name; all when no name matches).
function C:DataBosses(key)
  local m = ns.DUNGEON_MAPS[ns.BaseKey(key)]
  local inst = m and ns.EncounterData()[m[1]]
  if not inst then return nil end
  local all, mine = {}, {}
  for i = 2, #inst do
    local b = { id = inst[i][1], name = inst[i][2], tok = "e" .. inst[i][1] }
    all[#all + 1] = b
    if #m == 1 or has(m, b.name) then mine[#mine + 1] = b end
  end
  if #mine == 0 then mine = all end
  return mine, all
end

-- Dungeons and raids of the catalog without boss data for this game version (/jtf selftest: on Forever the data must
-- cover them all; tools/update-game-data.ps1 rebuilds it from a new build).
function C:NoBossData()
  local out = {}
  for _, list in ipairs({ ns.DUNGEONS, ns.RAIDS }) do
    for _, d in ipairs(list) do if not self:DataBosses(d[1]) then out[#out + 1] = d[1] end end
  end
  table.sort(out)
  return out
end

-- The bosses of a dungeon in order: { { tok, name, id } }, and where the list comes from ("data" or "learned").
-- Bosses learned on a kill that are not in the data are added at the end.
function C:Bosses(key)
  local list, src = {}, "learned"
  local mine = self:DataBosses(key)
  if mine then
    for _, b in ipairs(mine) do list[#list + 1] = b end
    src = "data"
  end
  for _, name in ipairs(ns.db.learned and ns.db.learned[ns.BaseKey(key)] or {}) do
    local known = false
    for _, b in ipairs(list) do if b.name == name then known = true end end
    if not known then list[#list + 1] = { name = name, tok = "n" .. name } end
  end
  return list, src
end

-- The bosses needed for a clear when Journey Admin chose none: every boss from the game's data, except rare
-- spawns and summoned bosses (ns.OPTIONAL_BOSSES). Learned bosses are never needed by themselves: the list is not
-- known to be complete, so the leader chooses them.
function C:DefaultNeeded(key)
  local out = {}
  for _, b in ipairs(self:DataBosses(key) or {}) do
    if not ns.OPTIONAL_BOSSES[b.name] then out[#out + 1] = b.tok end
  end
  return out
end

-- Tokens of the needed bosses of a dungeon in this fellowship's journey.
function C:Needed(f, key)
  local p = f.journey.place[key]
  if p and p.bosses then return p.bosses end
  return self:DefaultNeeded(key)
end

-- How many needed bosses a Hero was there for, and how many are needed.
function C:Progress(f, key, name)
  local needed = self:Needed(f, key)
  local k = f.kills[key] and f.kills[key][name] or {}
  local n = 0
  for _, tok in ipairs(needed) do if k[tok] then n = n + 1 end end
  return n, #needed
end

function C:Learn(key, boss)
  if type(boss) ~= "string" or boss == "" then return end
  for _, b in ipairs(self:Bosses(key)) do if b.name == boss then return end end
  key = ns.BaseKey(key)
  ns.db.learned = ns.db.learned or {}
  local list = ns.db.learned[key] or {}
  list[#list + 1] = boss
  ns.db.learned[key] = list
end

-- Dungeons in the instance with this ID, or (for dungeons not in the data yet) this name.
function C:KeysHere(instID, iname)
  local list = {}
  local function check(key, name)
    local m = ns.DUNGEON_MAPS[key]
    local known = m and ns.EncounterData()[m[1]]
    if (known and instID and m[1] == instID) or (not known and iname and name == iname) then list[#list + 1] = key end
  end
  for _, d in ipairs(ns.DUNGEONS) do check(d[1], d[2]) end
  for _, r in ipairs(ns.RAIDS) do check(r[1], r[2]) end
  return list
end

-- The placements of a dungeon in this fellowship's journey ("brd", "brd#2"), or the dungeon's own key when it is
-- not placed (raids, and dungeons outside the journey). A kill counts for each; their needed bosses decide.
function C:Placements(f, base)
  local out = {}
  for key in pairs(f.journey.place) do if ns.BaseKey(key) == base then out[#out + 1] = key end end
  if #out == 0 then out[1] = base end
  table.sort(out)
  return out
end

-- The boss of key that died: { tok, name } by encounter ID or name, or nil when it belongs to another dungeon of
-- the same instance. A boss the data does not know is learned (unless the instance is shared).
function C:Match(key, encounterID, name)
  for _, b in ipairs(self:Bosses(key)) do
    if (encounterID and b.id == encounterID) or (name and b.name == name) then return b end
  end
  local _, all = self:DataBosses(key)
  for _, b in ipairs(all or {}) do
    if (encounterID and b.id == encounterID) or (name and b.name == name) then return nil end
  end
  local m = ns.DUNGEON_MAPS[ns.BaseKey(key)]
  if not name or (all and m and #m > 1) then return nil end
  self:Learn(key, name)
  return { name = name, tok = "n" .. name }
end

---------------------------------------------------------------------------
-- The group
---------------------------------------------------------------------------
local function unitName(unit)
  local n, r = UnitName(unit)
  if not n or secret(n) or secret(r) then return nil end
  return (r and r ~= "") and (n .. "-" .. r) or ns.FullName(n)
end

-- Heroes of the fellowship in this character's group (this character first). "/jtf debug group" adds pretend Heroes.
function C:GroupHeroes(f)
  local out, seen = {}, {}
  local function add(name)
    if name and f.members[name] and not seen[name] then seen[name] = true; out[#out + 1] = name end
  end
  add(ns.Me())
  local raid = IsInRaid and IsInRaid()
  for i = 1, raid and 40 or 4 do add(unitName((raid and "raid" or "party") .. i)) end
  for _, name in ipairs(ns.Dev and ns.Dev.group or {}) do add(name) end
  return out
end

---------------------------------------------------------------------------
-- History
---------------------------------------------------------------------------
function C:Log(f, e)
  e.time = e.time or time()
  e.id = e.id or table.concat({ e.type, e.key or "", e.time, e.text or "" }, ":")
  local pos = #f.history + 1
  for i, h in ipairs(f.history) do if h.time <= e.time then pos = i; break end end
  table.insert(f.history, pos, e)
  while #f.history > self.HISTORY_MAX do table.remove(f.history) end
  return e
end

-- The text of an entry.
function C:Text(e)
  if e.type ~= "run" then return e.text or "" end
  local names = e.names or {}
  local text
  if e.of and e.of > 1 and #names >= e.of then text = L.H_RUN_ALL:format(dname(e.key), #names)
  else text = L.H_RUN:format(dname(e.key), andList(names)) end
  if (e.bossesOf or 0) > 0 then text = text .. L.H_RUN_BOSSES:format(e.bossesKilled or 0, e.bossesOf) end
  local cleared = e.cleared or {}
  if #cleared > 0 then
    text = text .. (#cleared >= #names and L.H_RUN_CLEARED or L.H_RUN_CLEARED_FOR:format(andList(cleared)))
  end
  return text
end

-- The status chip of an entry and its colour (nil: no chip).
function C:Status(e)
  if e.type == "run" then
    if e.ok then return L.ST_COUNTED, "2E7A3E" end
    if e.reason == "locked" then return L.ST_LOCKED, "B0321E" end
    local n = #(e.names or {})
    return (n == 1 and L.ST_NOT_COUNTED_1 or L.ST_NOT_COUNTED):format(n, e.need or 0), "B0321E"
  end
  if e.type == "leader" then return L.ST_LEADER, "7A6A55" end
  if e.type == "cap" then return L.ST_CAP, "B0321E" end
  if e.type == "session" then return L.ST_SESSION, "3D6B8A" end
  return nil
end

C.ICON = { run = "hist_run", mark = "hist_mark", undo = "hist_undo", chapter = "hist_chapter", cap = "hist_cap",
  session = "hist_session" }

-- History entries for a filter ("all", "run", "leader", "cap").
function C:Entries(f, filter)
  local list = {}
  for _, e in ipairs(f.history) do if filter == "all" or e.type == filter then list[#list + 1] = e end end
  return list
end

-- Totals: runs that counted, runs that did not, leader changes, over the cap.
function C:Totals(f)
  local t = { 0, 0, 0, 0 }
  for _, e in ipairs(f.history) do
    if e.type == "run" then t[e.ok and 1 or 2] = t[e.ok and 1 or 2] + 1
    elseif e.type == "leader" then t[3] = t[3] + 1
    elseif e.type == "cap" then t[4] = t[4] + 1 end
  end
  return t
end

-- A chapter unlocks when it becomes the current chapter.
function C:CheckChapter(f)
  local cur = J:CurrentIndex(f)
  local last = tonumber(f.lastChapter)
  if last and cur > last then
    for n = last + 1, cur do
      local ch = f.journey.chapters[n]
      if ch then self:Log(f, { type = "chapter", icon = "chapter", ch = n, text = L.H_CHAPTER:format(ns.Journey.Roman(n), ch.name) }) end
    end
  end
  f.lastChapter = cur
end

---------------------------------------------------------------------------
-- Kills
---------------------------------------------------------------------------
-- A Hero who was there for every needed boss has cleared the dungeon. Returns true when that is new.
function C:Grant(f, key, name, t)
  if f.runs[key] and f.runs[key][name] then return false end
  local n, of = self:Progress(f, key, name)
  if of == 0 or n < of then return false end
  f.runs[key] = f.runs[key] or {}
  f.runs[key][name] = t
  return true
end

-- After Journey Admin changes the needed bosses: Heroes who now have them all get the clear.
function C:Reevaluate(f)
  for key, heroes in pairs(f.kills) do
    if ns.Endgame:Tracked(f, key) then
      for name, toks in pairs(heroes) do
        local last = 0
        for _, t in pairs(toks) do last = math.max(last, t) end
        if f.members[name] then self:Grant(f, key, name, last) end
      end
    end
  end
end

-- Records the kill of boss tok in key at time t with these Heroes (the same kill from several reports is one).
-- Returns the history entry (nil when the boss is not needed), the Heroes who cleared it now, and true when the
-- dungeon became cleared for the fellowship.
function C:Record(f, key, t, names, tok)
  local was = J:Cleared(f, key)
  local needed = self:Needed(f, key)
  local open = J:Open(f, key)
  local ok = open and #names >= f.rules.minHeroes
  local newly = {}
  if ok then
    local undone = f.undone[key] or {}
    f.kills[key] = f.kills[key] or {}
    for _, n in ipairs(names) do
      if f.members[n] and t > (undone["*"] or 0) and t > (undone[n] or 0) then
        local k = f.kills[key][n] or {}
        k[tok] = math.max(k[tok] or 0, t)
        f.kills[key][n] = k
        if self:Grant(f, key, n, t) then newly[#newly + 1] = n end
      end
    end
    if not next(f.kills[key]) then f.kills[key] = nil end
  end
  -- History: one entry per visit, for the bosses that matter (or any, when none are chosen yet).
  local e
  if has(needed, tok) or #needed == 0 then
    for _, h in ipairs(f.history) do
      if h.type == "run" and h.key == key and t > h.time - self.SAME_RUN and t < (h.last or h.time) + self.SAME_RUN then e = h; break end
    end
    if not e then e = self:Log(f, { type = "run", icon = "run", key = key, time = t, names = {}, killed = {}, cleared = {}, of = F:Count(f) }) end
    for _, n in ipairs(names) do if not has(e.names, n) then e.names[#e.names + 1] = n end end
    for _, n in ipairs(newly) do if not has(e.cleared, n) then e.cleared[#e.cleared + 1] = n end end
    table.sort(e.names); table.sort(e.cleared)
    e.killed[tok] = true
    e.last = math.max(e.last or e.time, t)
    e.time = math.min(e.time, t)
    e.need = f.rules.minHeroes
    local count = 0
    for _, nt in ipairs(needed) do if e.killed[nt] then count = count + 1 end end
    e.bossesKilled, e.bossesOf = count, #needed
    if ok then e.ok, e.reason = true, nil
    elseif not e.ok then e.ok, e.reason = false, (not open) and "locked" or "few" end
  end
  return e, newly, not was and J:Cleared(f, key)
end

-- A copy from another Hero replaces ours: keep the kills and runs we heard of that the copy does not have yet.
function C:Merge(into, from)
  for key, heroes in pairs(from.kills or {}) do
    if ns.Endgame:Tracked(into, key) then
      local undone = into.undone[key] or {}
      for name, toks in pairs(heroes) do
        if into.members[name] then
          for tok, t in pairs(toks) do
            if t > (undone["*"] or 0) and t > (undone[name] or 0) then
              into.kills[key] = into.kills[key] or {}
              local k = into.kills[key][name] or {}
              k[tok] = math.max(k[tok] or 0, t)
              into.kills[key][name] = k
            end
          end
        end
      end
    end
  end
  self:Reevaluate(into)
  -- Entries a copy left out (it carries only the newest ones, Fellowship/Sync.lua) stay: the same id is the same entry.
  local ids = {}
  for _, h in ipairs(into.history) do if h.id then ids[h.id] = true end end
  for _, e in ipairs(from.history or {}) do
    if e.type ~= "run" and e.id and not ids[e.id] then self:Log(into, e) end
  end
  for _, e in ipairs(from.history or {}) do
    if e.type == "run" and ns.Endgame:Tracked(into, e.key) then
      local found = false
      for _, h in ipairs(into.history) do
        if h.type == "run" and h.key == e.key and e.time < (h.last or h.time) + self.SAME_RUN and (e.last or e.time) > h.time - self.SAME_RUN then found = true; break end
      end
      if not found then self:Log(into, e) end
    end
  end
end

---------------------------------------------------------------------------
-- Kills compared at login (27 Oct 2026). A kill reaches the Adventurers who are online when it happens; HELLO and
-- HI carry a fingerprint of all kills, and on a difference each side sends the other its kills of the dungeons where
-- the two differ (KILLD: one fingerprint per dungeon, KILLS: those dungeons' kills and run entries). Kills only add
-- up (an undo is a numbered change), so merging both ways makes both copies the same.
---------------------------------------------------------------------------
local function hash(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
  return h
end

function C:KeyDigests(f)
  local out = {}
  for key, heroes in pairs(f.kills or {}) do out[key] = hash(ns.Serialize.Encode(heroes)) end
  return out
end

function C:Digest(f) return hash(ns.Serialize.Encode(self:KeyDigests(f))) end

-- Their fingerprint differs: ask with ours per dungeon (they answer with the dungeons that differ).
function C:Compare(f, to, theirs)
  if not theirs or theirs == self:Digest(f) then return end
  Comm:Send(to, "KILLD", { fid = f.id, d = self:KeyDigests(f) })
end

local function memberOf(sender, d)
  local f = type(d) == "table" and F:Get(d.fid)
  if not f or f.disbanded or not f.members[sender] or not f.members[ns.Me()] then return nil end
  return f
end

Comm:On("KILLD", function(sender, d)
  local f = memberOf(sender, d)
  if not f or type(d.d) ~= "table" then return end
  local mine, kills, keys = C:KeyDigests(f), {}, {}
  for key, digest in pairs(mine) do
    if d.d[key] ~= digest then kills[key] = f.kills[key]; keys[key] = 0 end
  end
  if not next(kills) then return end
  -- The newest run entries of those dungeons (three each), for the History.
  local history = {}
  for _, e in ipairs(f.history) do
    if e.type == "run" and keys[e.key] and keys[e.key] < 3 then keys[e.key] = keys[e.key] + 1; history[#history + 1] = e end
  end
  Comm:Send(sender, "KILLS", { fid = f.id, kills = kills, history = history })
end)

Comm:On("KILLS", function(sender, d)
  local f = memberOf(sender, d)
  if not f or type(d.kills) ~= "table" then return end
  -- Only well-formed kills: { key = { name = { boss = time } } }.
  local kills = {}
  for key, heroes in pairs(d.kills) do
    if type(key) == "string" and type(heroes) == "table" then
      for name, toks in pairs(heroes) do
        if type(name) == "string" and type(toks) == "table" then
          for tok, t in pairs(toks) do
            if type(tok) == "string" and tonumber(t) then
              kills[key] = kills[key] or {}
              kills[key][name] = kills[key][name] or {}
              kills[key][name][tok] = tonumber(t)
            end
          end
        end
      end
    end
  end
  local history = {}
  for _, e in ipairs(type(d.history) == "table" and d.history or {}) do
    if type(e) == "table" and e.type == "run" and type(e.key) == "string" and tonumber(e.time) and type(e.names) == "table"
      and type(e.killed) == "table" and type(e.cleared) == "table" then history[#history + 1] = e end
  end
  C:Merge(f, { kills = kills, history = history })
  F:Changed()
end)

function C:ClearedToast(key)
  ns:Toast("clear", L.TOAST_CLEARED, L.TOAST_CLEARED_TEXT:format(dname(key)), "chapter")
end

-- Boss b of key died with this character in the group: record it, tell the other Heroes, show it at once.
function C:Kill(f, key, b)
  local now = time()
  local id = key .. ":" .. b.tok
  if self.recent[id] and now - self.recent[id] < self.REPEAT then return end
  self.recent[id] = now
  local names = self:GroupHeroes(f)
  local e, newly, done = self:Record(f, key, now, names, b.tok)
  local me = ns.Me()
  for name in pairs(f.members) do
    if name ~= me then Comm:Send(name, "RUN", { fid = f.id, key = key, t = now, names = names, b = b.tok, bn = b.name }) end
  end
  if e then
    if e.ok then
      local n, of = self:Progress(f, key, me)
      ns:Print(L.KILL_PRINT:format(b.name, dname(key), n, of))
    else
      ns:Print(L.KILL_NOT:format(b.name, (self:Status(e))), true)
    end
  end
  if done then self:ClearedToast(key)
  elseif #newly > 0 then ns:Toast("clear", L.TOAST_CLEARED, L.TOAST_CLEARED_FOR:format(dname(key), andList(newly)), "chapter") end
  -- The final boss (the last in the game's list), or the kill that finished the clear: a picture of the group?
  if ns.Picture and (self:IsFinal(key, b) or done) then ns.Picture:Offer(key) end
  F:Changed()
end

-- Is b the dungeon's final boss (the last of the game's list for it)?
function C:IsFinal(key, b)
  local list = self:DataBosses(key)
  return list ~= nil and #list > 0 and list[#list].tok == b.tok
end

-- ENCOUNTER_END: a boss died in a dungeon of the journey.
function C:BossDown(encounterID, encounterName)
  local f = F:Current()
  if not f then return end
  local iname, itype, _, _, _, _, _, instID = GetInstanceInfo()
  if itype ~= "party" and itype ~= "raid" then return end
  if secret(encounterID) then encounterID = nil end
  if secret(encounterName) then encounterName = nil end
  if secret(iname) then iname = nil end
  if secret(instID) then instID = nil end
  for _, base in ipairs(self:KeysHere(instID, iname)) do
    for _, key in ipairs(self:Placements(f, base)) do
      if ns.Endgame:Tracked(f, key) then
        local b = self:Match(key, encounterID, encounterName)
        if b then self:Kill(f, key, b) end
      end
    end
  end
end

---------------------------------------------------------------------------
-- Mark cleared and Undo (ops; Fellowship:Apply calls ApplyOp after checking the "clears" permission)
---------------------------------------------------------------------------
function C:ApplyOp(f, op, by, t)
  local key = op.key
  local was = J:Cleared(f, key)
  local d, who = dname(key), ns.Short(by)
  -- The leader undoing a clear an earlier chapter needs takes the fellowship back to that chapter.
  local back = by == f.leader and op.k ~= "clear" and not op.on and J:ReopensChapter(f, key)
  f.undone[key] = f.undone[key] or {}
  if op.k == "clear" then
    local runs = f.runs[key] or {}
    local any = false
    for _, n in ipairs(type(op.names) == "table" and op.names or {}) do
      if f.members[n] then runs[n] = t; any = true end
    end
    if not any then return false end
    f.runs[key] = runs
    self:Log(f, { type = "leader", icon = "mark", time = t, text = L.H_MARKED:format(who, d) })
    F:Log(f, L.CHR_MARKED:format(who, d), t, "marked", by)
  elseif op.k == "unclear" then
    if not f.runs[key] and not f.kills[key] then return false end
    f.runs[key], f.kills[key] = nil, nil
    f.undone[key] = { ["*"] = t }
    self:Log(f, { type = "leader", icon = "undo", time = t, text = L.H_UNDID:format(who, d) })
    F:Log(f, L.CHR_UNDID:format(who, d), t, "undid", by)
  elseif op.k == "cell" then
    local n = op.name
    if type(n) ~= "string" or not f.members[n] then return false end
    if op.on then
      f.runs[key] = f.runs[key] or {}
      f.runs[key][n] = t
    else
      if not (f.runs[key] and f.runs[key][n]) then return false end
      f.runs[key][n] = nil
      if not next(f.runs[key]) then f.runs[key] = nil end
      if f.kills[key] then f.kills[key][n] = nil end
      f.undone[key][n] = t
    end
    self:Log(f, { type = "leader", icon = op.on and "mark" or "undo", time = t,
      text = (op.on and L.H_CELL_ON or L.H_CELL_OFF):format(who, ns.Short(n), d) })
  else
    return false
  end
  if not was and J:Cleared(f, key) then self:ClearedToast(key) end
  if back and not J:Cleared(f, key) then
    J:Reopen(f, back)
    F:Log(f, L.CHR_REOPENED:format(ns.Journey.Roman(back), f.journey.chapters[back].name), t, "reopened", by)
  end
  return true
end

-- For the Chapter page: mark cleared for every Hero who sets the pace, undo every clear, or flip one Hero's clear.
function C:Mark(key)
  local f = F:Current()
  return f ~= nil and F:Do({ k = "clear", key = key, names = J:Pacing(f) })
end
function C:Undo(key) return F:Do({ k = "unclear", key = key }) end
function C:Toggle(key, name)
  local f = F:Current()
  return f ~= nil and F:Do({ k = "cell", key = key, name = name, on = J:ClearedBy(f, key)[name] == nil })
end

---------------------------------------------------------------------------
-- Messages and events
---------------------------------------------------------------------------
Comm:On("RUN", function(sender, d)
  if type(d) ~= "table" or type(d.names) ~= "table" or type(d.key) ~= "string" or type(d.b) ~= "string" then return end
  local f = F:Get(d.fid)
  local t = tonumber(d.t)
  if not f or f.disbanded or not t or not f.members[sender] or not ns.Endgame:Tracked(f, d.key) then return end
  -- The sender reports its own group, so it must be in it; names outside the fellowship are dropped.
  local names, inGroup = {}, false
  for _, n in ipairs(d.names) do
    if type(n) == "string" and f.members[n] then
      names[#names + 1] = n
      if n == sender then inGroup = true end
    end
  end
  if not inGroup then return end
  if d.b:sub(1, 1) == "n" then C:Learn(d.key, d.b:sub(2)) end
  local _, _, done = C:Record(f, d.key, t, names, d.b)
  if done and f == F:Current() then C:ClearedToast(d.key) end
  F:Changed()
end)

ns:RegisterEvent("ENCOUNTER_END", function(_, encounterID, encounterName, _, _, success)
  if not secret(success) and (success == 1 or success == true) then C:BossDown(encounterID, encounterName) end
end)

local function check()
  local f = F:Current()
  if f then C:CheckChapter(f) end
end
ns:On("FELLOWSHIP", check)
ns:On("HEROES", check)
ns:On("JOINED", check)
