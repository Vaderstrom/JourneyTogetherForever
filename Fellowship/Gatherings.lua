-- Gatherings (SPEC §6): any Hero schedules a time to play together: a dungeon of the journey, a few words ("questing
-- in Westfall"), or both. Heroes answer Yes / Maybe / No. They are ops (op k = "gather", a = new / answer / cancel),
-- so every Hero keeps the same list (Fellowship/Fellowship.lua). 15 minutes before, those who said Yes or Maybe get a
-- reminder; when it starts, the organizer's addon invites them (or, if the organizer is offline, the first online Hero
-- who said Yes, by name).
local _, ns = ...
local L = ns.L
local F, Hr = ns.Fellowship, ns.Hero
local G = { REMIND = 15 * 60, KEEP = 3 * 3600, AHEAD = 14 * 86400, TICK = 30, TEXT_MAX = 60, DROP = 86400 }
ns.Gatherings = G

local ANSWERS = { yes = true, maybe = true, no = true }

local function list(f)
  if type(f.gatherings) ~= "table" then f.gatherings = {} end
  return f.gatherings
end

-- "Sat 20:00" (in the player's own time).
function G.When(at) return date(L.G_DATE_FORMAT, at) end

-- "The Deadmines", "questing in Westfall", or "The Deadmines: bring potions".
function G.What(g)
  local d = g.key and ns.Dungeon(g.key)
  if d and g.text then return L.G_WHAT_BOTH:format(d[2], g.text) end
  return d and d[2] or g.text or ""
end

---------------------------------------------------------------------------
-- Ops
---------------------------------------------------------------------------
-- Gatherings that started more than a day before t are dropped when a new one is scheduled (the op's time, so every
-- copy drops the same ones). The History keeps the lines.
function G:Prune(f, t)
  for id, g in pairs(list(f)) do
    if type(g) ~= "table" or (tonumber(g.at) or 0) + self.DROP < t then f.gatherings[id] = nil end
  end
end

function G:Apply(f, op, by, t)
  local all = list(f)
  if op.a == "new" then
    self:Prune(f, t)
    local key = op.key
    if key ~= nil and (type(key) ~= "string" or not ns.Dungeon(key)) then return false end
    local text = type(op.text) == "string" and strtrim(op.text) or nil
    if text == "" then text = nil end
    if text and #text > self.TEXT_MAX then return false end
    local at, id = tonumber(op.at), op.id
    if (not key and not text) or not at or type(id) ~= "string" or all[id] or at < t - 3600 or at > t + self.AHEAD then return false end
    all[id] = { id = id, by = by, key = key, text = text, at = math.floor(at), answers = { [by] = "yes" }, t = t }
    F:Log(f, L.CHR_GATHER:format(ns.Short(by), G.What(all[id]), G.When(at)), t, "gather", by)
  elseif op.a == "answer" then
    local g = all[op.id]
    if not g or not ANSWERS[op.answer] then return false end
    g.answers[by] = op.answer
  elseif op.a == "cancel" then
    local g = all[op.id]
    local rank = ns.Permissions.Rank(f, by)
    if not g or (g.by ~= by and rank ~= "leader") then return false end
    all[op.id] = nil
    F:Log(f, L.CHR_GATHER_CANCEL:format(G.What(g), G.When(g.at)), t, "gathercancel")
  else
    return false
  end
  return true
end

function G:Schedule(key, text, at)
  local me = ns.Me()
  return F:Do({ k = "gather", a = "new", id = me .. "-" .. time(), key = key, text = text, at = at })
end
function G:Answer(id, answer) return F:Do({ k = "gather", a = "answer", id = id, answer = answer }) end
function G:Cancel(id) return F:Do({ k = "gather", a = "cancel", id = id }) end

-- May I cancel this Gathering? The organizer and the leader.
function G:CanCancel(f, g)
  local rank = ns.Permissions.Rank(f, ns.Me())
  return g.by == ns.Me() or rank == "leader"
end

---------------------------------------------------------------------------
-- For the pages
---------------------------------------------------------------------------
-- Gatherings that have not ended (started less than 3 hours ago), soonest first.
function G:Upcoming(f)
  local out = {}
  for _, g in pairs(list(f)) do
    if g.at + self.KEEP > time() then out[#out + 1] = g end
  end
  table.sort(out, function(a, b) if a.at ~= b.at then return a.at < b.at end return a.id < b.id end)
  return out
end

-- Counts of answers: yes, maybe, no.
function G.Counts(g)
  local c = { yes = 0, maybe = 0, no = 0 }
  for _, a in pairs(g.answers) do c[a] = (c[a] or 0) + 1 end
  return c
end

-- "by Brannic  ·  3 yes, 1 maybe"
function G.Line(g)
  local c = G.Counts(g)
  return L.G_LINE:format(ns.Short(g.by), c.yes, c.maybe, c.no)
end

-- Upcoming Gatherings I have not answered (for the inbox).
function G:Unanswered(f)
  local out, me = {}, ns.Me()
  for _, g in ipairs(self:Upcoming(f)) do
    if not g.answers[me] and g.at > time() then out[#out + 1] = g end
  end
  return out
end

---------------------------------------------------------------------------
-- Reminders and invites
---------------------------------------------------------------------------
local function seen(kind)
  ns.char[kind] = type(ns.char[kind]) == "table" and ns.char[kind] or {}
  return ns.char[kind]
end

-- Who invites when it starts: the organizer if online, else the first online Hero who said Yes, by name.
function G:Host(f, g)
  if f.members[g.by] and Hr:Online(f, g.by) then return g.by end
  local names = {}
  for name, a in pairs(g.answers) do if a == "yes" and f.members[name] and Hr:Online(f, name) then names[#names + 1] = name end end
  table.sort(names)
  return names[1]
end

function G:Tick()
  local f = F:Current()
  if not f then return end
  local me, now = ns.Me(), time()
  local reminded, started = seen("gReminded"), seen("gStarted")
  for _, g in ipairs(self:Upcoming(f)) do
    local mine = g.answers[me]
    local going = mine == "yes" or mine == "maybe"
    if going and not reminded[g.id] and now >= g.at - self.REMIND and now < g.at then
      reminded[g.id] = true
      ns:Toast("gathering", L.G_SOON, L.G_SOON_TEXT:format(G.What(g), G.When(g.at)), "gatherings")
    end
    if now >= g.at and now < g.at + 30 * 60 and not started[g.id] then
      started[g.id] = true
      local host = self:Host(f, g)
      if going then ns:Toast("gathering", L.G_START, L.G_START_TEXT:format(G.What(g), host and ns.Short(host) or "-"), "gatherings") end
      if host == me then
        local names = {}
        for name, a in pairs(g.answers) do
          if name ~= me and (a == "yes" or a == "maybe") and f.members[name] and Hr:Online(f, name) then names[#names + 1] = name end
        end
        table.sort(names)
        if #names > 0 then ns.Together:Invite(names) end
      end
    end
  end
end

ns:On("LOGIN", function() C_Timer.NewTicker(G.TICK, function() G:Tick() end) end)
