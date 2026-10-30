-- Session recap (SPEC §6, M25): playing together, summed up afterwards.
-- A session starts when another Adventurer of the fellowship is in your group and ends when none has been for
-- END_AFTER seconds (or at logout). A session of at least MIN seconds is kept for this character (the last MAX, in
-- ns.char.sessions, newest first) and shown in a big toast; History lists them under Sessions. They are personal:
-- never sent to the others.
--   session = { fid, start, stop, with = { names }, levels = { { name, from, to } } (you first), quests, bosses,
--     runs = { { key, cleared } } (the fellowship's runs you were in), chapters = { n } }
-- A /reload keeps the session going: it is saved at logout and taken up again when you are back within END_AFTER.
local _, ns = ...
local L = ns.L
local F, Hr = ns.Fellowship, ns.Hero
local S = {}
ns.Session = S

S.END_AFTER = 120
S.MIN = 600
S.MAX = 50
S.TICK = 30

local function has(list, v)
  for _, x in ipairs(list or {}) do if x == v then return true end end
  return false
end

function S:List()
  ns.char.sessions = type(ns.char.sessions) == "table" and ns.char.sessions or {}
  return ns.char.sessions
end

-- "45 min", "1 h", "1 h 25 min".
function S.Duration(sec)
  local m = math.floor(math.max(0, sec) / 60 + 0.5)
  if m < 60 then return L.MINUTES_N:format(math.max(1, m)) end
  local h, rest = math.floor(m / 60), m % 60
  return rest == 0 and L.SES_H:format(h) or L.SES_HM:format(h, rest)
end

---------------------------------------------------------------------------
-- Watching the group
---------------------------------------------------------------------------
-- On group changes and every TICK seconds: starts a session, notes who joins and their levels, ends it.
function S:Tick()
  local f = F:Current()
  local cur = self.cur
  if cur and (not f or cur.fid ~= f.id) then self:End(); cur = nil end
  if not f then return end
  local now, me = time(), ns.Me()
  local others = {}
  for _, name in ipairs(ns.Clears:GroupHeroes(f)) do if name ~= me then others[#others + 1] = name end end
  if #others > 0 and not cur then
    cur = { fid = f.id, start = now, last = now, with = {}, from = { [me] = Hr:Level(f, me) }, to = {}, quests = 0, bosses = 0 }
    self.cur = cur
  end
  if not cur then return end
  for _, name in ipairs(others) do
    if not cur.from[name] then cur.from[name] = Hr:Level(f, name); cur.with[#cur.with + 1] = name end
  end
  for name in pairs(cur.from) do cur.to[name] = Hr:Level(f, name) end
  if #others > 0 then cur.last = now
  elseif now - cur.last >= self.END_AFTER then self:End() end
end

-- What the session did, from what was counted and the fellowship's history between its start and end.
function S:Recap(f, cur)
  local me = ns.Me()
  local rec = { fid = cur.fid, start = cur.start, stop = cur.last, with = cur.with, levels = {}, quests = cur.quests,
    bosses = cur.bosses, runs = {}, chapters = {} }
  local function level(name)
    local from = cur.from[name]
    if from then rec.levels[#rec.levels + 1] = { name, from, math.max(from, cur.to[name] or from) } end
  end
  level(me)
  for _, name in ipairs(cur.with) do level(name) end
  for i = #f.history, 1, -1 do
    local e = f.history[i]
    if (e.last or e.time) >= cur.start and e.time <= cur.last then
      if e.type == "run" and has(e.names, me) then rec.runs[#rec.runs + 1] = { key = e.key, cleared = has(e.cleared, me) }
      elseif e.type == "chapter" and e.ch then rec.chapters[#rec.chapters + 1] = e.ch end
    end
  end
  return rec
end

-- Ends the session: kept and shown when it was long enough (quiet: kept only). Returns the recap or nil.
function S:End(quiet)
  local cur = self.cur
  self.cur = nil
  local f = cur and F:Get(cur.fid)
  if not f or cur.last - cur.start < self.MIN then return nil end
  local rec = self:Recap(f, cur)
  local list = self:List()
  table.insert(list, 1, rec)
  while #list > self.MAX do table.remove(list) end
  if not quiet then self:Toast(rec) end
  return rec
end

function S:Toast(rec)
  return ns:Toast("session", L.T_SESSION:format(self.Duration(rec.stop - rec.start)), self:Text(rec, true), "chronicle#session")
end

---------------------------------------------------------------------------
-- In words
---------------------------------------------------------------------------
local function names(list, most)
  local out = {}
  for i, n in ipairs(list) do
    if most and i > most then out[#out] = L.SES_MORE:format(#list - most + 1); break end
    out[#out + 1] = ns.Short(n)
  end
  if #out <= 1 then return out[1] or "" end
  return table.concat(out, ", ", 1, #out - 1) .. L.AND .. out[#out]
end

-- "With Brannic and Elyra. Levels: you 20 » 22, Brannic 21 » 22. Dungeons: The Deadmines (cleared). 7 bosses,
-- 9 quests turned in. Chapter IV unlocked." Short (the toast): at most three names and three levels.
function S:Text(rec, short)
  local parts = { L.SES_WITH:format(names(rec.with, short and 3)) }
  local lv = {}
  for _, x in ipairs(rec.levels or {}) do
    if x[3] > x[2] and not (short and #lv >= 3) then
      lv[#lv + 1] = L.SES_LEVEL:format(x[1] == ns.Me() and L.SES_YOU or ns.Short(x[1]), x[2], x[3])
    end
  end
  if #lv > 0 then parts[#parts + 1] = L.SES_LEVELS:format(table.concat(lv, ", ")) end
  local runs = {}
  for _, r in ipairs(rec.runs or {}) do
    local d = ns.Dungeon(ns.BaseKey(r.key))
    local name = d and d[2] or r.key
    runs[#runs + 1] = r.cleared and L.SES_CLEARED:format(name) or name
  end
  if #runs > 0 then parts[#parts + 1] = L.SES_RUNS:format(table.concat(runs, ", ")) end
  local counts = {}
  if (rec.bosses or 0) > 0 then counts[#counts + 1] = (rec.bosses == 1 and L.SES_BOSS_1 or L.SES_BOSSES):format(rec.bosses) end
  if (rec.quests or 0) > 0 then counts[#counts + 1] = (rec.quests == 1 and L.SES_QUEST_1 or L.SES_QUESTS):format(rec.quests) end
  if #counts > 0 then parts[#parts + 1] = table.concat(counts, ", ") .. "." end
  local chs = {}
  for i, n in ipairs(rec.chapters or {}) do chs[i] = ns.Journey.Roman(n) end
  if #chs > 0 then parts[#parts + 1] = (#chs == 1 and L.SES_CHAPTER or L.SES_CHAPTERS):format(table.concat(chs, ", ")) end
  if #parts == 1 then parts[2] = L.SES_QUIET end
  return table.concat(parts, " ")
end

-- History entries for this fellowship's sessions (the History page shows them under Sessions and in All).
function S:Entries(f)
  local out = {}
  for _, rec in ipairs(self:List()) do
    if rec.fid == f.id and tonumber(rec.stop) and tonumber(rec.start) then
      out[#out + 1] = { type = "session", icon = "session", time = rec.stop, id = "session:" .. rec.start, rec = rec,
        text = L.SES_HISTORY:format(self.Duration(rec.stop - rec.start), self:Text(rec)) }
    end
  end
  return out
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
ns:RegisterEvent("GROUP_ROSTER_UPDATE", function() S:Tick() end)
ns:RegisterEvent("QUEST_TURNED_IN", function() if S.cur then S.cur.quests = S.cur.quests + 1 end end)
ns:RegisterEvent("ENCOUNTER_END", function(_, _, _, _, _, success)
  if issecretvalue and issecretvalue(success) then return end
  if S.cur and (success == 1 or success == true) then S.cur.bosses = S.cur.bosses + 1 end
end)

-- Logout (and /reload): the session is saved as it is; back within END_AFTER it goes on, else it ends there.
ns:RegisterEvent("PLAYER_LOGOUT", function()
  if S.cur then S:Tick(); ns.char.sessionOpen = S.cur end
end)

function S:Resume()
  local open = ns.char.sessionOpen
  ns.char.sessionOpen = nil
  if type(open) ~= "table" or not tonumber(open.last) or not tonumber(open.start) or type(open.from) ~= "table" then return end
  open.with, open.to = type(open.with) == "table" and open.with or {}, type(open.to) == "table" and open.to or {}
  open.quests, open.bosses = tonumber(open.quests) or 0, tonumber(open.bosses) or 0
  self.cur = open
  if time() - open.last >= self.END_AFTER then self:End(true) end
end

ns:On("LOGIN", function()
  S:Resume()
  C_Timer.NewTicker(S.TICK, function() S:Tick() end)
end)
