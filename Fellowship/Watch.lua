-- Watching another character's fellowship (27 Oct 2026): while you play an alt, the book can show the fellowship of
-- another character on your account, read-only and live, so you can follow your mates (for example while your main
-- waits at the cap). Each Companion shares the other characters on their account (HeroState.alts); a Companion's
-- addon answers only those. Messages:
--   WATCHQ  alt -> every Companion of the watched fellowship: who is online and can answer? { fid, v }
--   WATCHA  Companion -> alt: I can. { fid, v }
--   WATCHG  alt -> the first who answered: send it. { fid, v }
--   WATCHS  Companion -> alt: the whole fellowship when the versions differ (Sync:Copy), and every Companion's level,
--           XP and when last heard. { fid, f?, h = { name = state } }
-- The alt asks every POLL seconds in the background (a toast when the watched fellowship opens a chapter), and every
-- LIVE seconds while the book shows it. Nothing is ever sent as the watched character, and nothing can be changed.
-- The book draws the watched fellowship as that character (Watch.rendering: F:Current and ns.Me answer for it while
-- a page is drawn; UI/Window.lua).
local _, ns = ...
local L = ns.L
local F, Comm, Hr, J = ns.Fellowship, ns.Comm, ns.Hero, ns.Journey
local WT = { POLL = 300, LIVE = 60, active = false, rendering = false, last = {}, source = {}, pending = {}, onNews = {} }
ns.Watch = WT

-- The fellowships of this account's other characters that this one can watch: { { key, f } } by name.
function WT:Targets()
  local me, out = ns.Me(), {}
  for key, c in pairs(ns.db and ns.db.characters or {}) do
    local f = key ~= me and c.fellowshipId and F:Get(c.fellowshipId)
    if f and not f.disbanded and f.members[key] and not f.members[me] then out[#out + 1] = { key = key, f = f } end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end

-- The fellowship the book draws instead of your own: a watched one, or the walkthrough's sample (WT.demo, drawn as
-- you with a rank, never saved; UI/Walkthrough.lua).
function WT:Fellowship()
  if self.demo then return self.demo end
  return self.fid and F:Get(self.fid) or nil
end

-- Asks every Companion of f but the watched character (that is you, not playing it) who can answer.
function WT:Ask(key, f)
  self.pending[f.id] = true
  for name in pairs(f.members) do if name ~= key then Comm:Send(name, "WATCHQ", { fid = f.id, v = f.v }) end end
end

-- Asks for news of every watchable fellowship, or of one.
function WT:Poll(onlyFid)
  for _, t in ipairs(self:Targets()) do
    if not onlyFid or t.f.id == onlyFid then self:Ask(t.key, t.f) end
  end
end

-- Opens the book on the fellowship of another character of this account (key "Name-Realm").
function WT:Open(key)
  local c = ns.db.characters[key]
  local f = c and F:Get(c.fellowshipId)
  if not f or f.disbanded or not f.members[key] or key == ns.Me() then return false end
  self.fid, self.as, self.active = f.id, key, true
  self:Poll(f.id)
  ns.Window.page = "overview"
  ns.Window:Open("overview")
  return true
end

function WT:Close()
  self.active, self.fid, self.as = false, nil, nil
  ns.Window.page = "overview"
  ns.Window:Refresh()
end

-- When the copy of f is from: the last answer this session, else when the watched character was last played.
function WT:AsOf(f)
  local c = ns.db.characters[self.as or ""]
  return self.last[f.id] or (c and c.lastSeen) or f.updated or time()
end

-- "Live, 2 min ago from Brannic" or "as of 3 hours ago" (no Companion has answered this session).
function WT:Freshness(f)
  local t, src = self.last[f.id], self.source[f.id]
  if t then return L.WATCH_LIVE:format(ns.TimeAgo(t), ns.Short(src)) end
  return L.WATCH_AS_OF:format(ns.TimeAgo(self:AsOf(f)))
end

---------------------------------------------------------------------------
-- A Companion's side: answer the alts of the fellowship's Companions
---------------------------------------------------------------------------
local function allowed(f, sender)
  if not f or f.disbanded or not f.members[ns.Me()] or f.members[sender] then return false end
  for name, h in pairs(f.heroes or {}) do
    if f.members[name] and type(h.alts) == "table" then
      for _, a in ipairs(h.alts) do if a == sender then return true end end
    end
  end
  return false
end
WT.Allowed = allowed

-- Is alt one of the other characters on main's account (as main's addon shared them)?
function WT.IsAlt(f, main, alt)
  local h = f.heroes and f.heroes[main]
  if not h or type(h.alts) ~= "table" then return false end
  for _, a in ipairs(h.alts) do if a == alt then return true end end
  return false
end

Comm:On("WATCHQ", function(sender, d)
  local f = type(d) == "table" and F:Get(d.fid)
  if allowed(f, sender) then Comm:Send(sender, "WATCHA", { fid = f.id, v = f.v }, true) end
end)

Comm:On("WATCHG", function(sender, d)
  local f = type(d) == "table" and F:Get(d.fid)
  if not allowed(f, sender) then return end
  local heroes = {}
  for name, h in pairs(f.heroes or {}) do
    if f.members[name] then
      heroes[name] = { level = h.level, xp = h.xp, xpMax = h.xpMax, rested = h.rested, zone = h.zone, class = h.class,
        className = h.className, race = h.race, ver = h.ver, pace = h.pace, t = h.t, seq = h.seq, heard = h.offline and 0 or h.heard }
    end
  end
  local me = Hr:MyState()
  local mine = Hr:Get(f, ns.Me())
  me.alts, me.heard, me.seq = nil, time(), mine and mine.seq
  heroes[ns.Me()] = me
  local full = (tonumber(d.v) or 0) ~= f.v and ns.Sync:Copy(f) or nil
  Comm:Send(sender, "WATCHS", { fid = f.id, f = full, h = heroes }, false, true)
end)

---------------------------------------------------------------------------
-- The alt's side
---------------------------------------------------------------------------
Comm:On("WATCHA", function(sender, d)
  local f = type(d) == "table" and F:Get(d.fid)
  if not f or not f.members[sender] or not WT.pending[f.id] then return end
  WT.pending[f.id] = nil
  Comm:Send(sender, "WATCHG", { fid = f.id, v = f.v }, true)
end)

Comm:On("WATCHS", function(sender, d)
  local mine = type(d) == "table" and F:Get(d.fid)
  if not mine or mine.disbanded or not mine.members[sender] or mine.members[ns.Me()] then return end
  local before = J:CurrentIndex(mine)
  if type(d.f) == "table" then
    local snap = F:Sanitize(d.f)
    if snap and snap.id == mine.id and snap.members[sender] and snap.v >= mine.v then
      ns.Sync:KeepLocal(snap, mine)
      ns.db.fellowships[snap.id] = snap
      mine = snap
    end
  end
  if type(d.h) == "table" then
    for name, s in pairs(d.h) do
      if type(name) == "string" and type(s) == "table" and mine.members[name] then
        -- heard = 0: offline. Keep when they were last heard (it said "Seen just now"; seen in the tour); for a
        -- character of this account, when it was last played.
        local heard = tonumber(s.heard)
        local earlier = mine.heroes and mine.heroes[name] and mine.heroes[name].heard
        local played = ns.db.characters[name] and ns.db.characters[name].lastSeen
        -- (Others than the sender: passed on, taken when newer.)
        Hr:Store(mine, name, s, heard and heard > 0 and heard or played or earlier or mine.members[name].joined, name ~= sender)
        if heard == 0 then mine.heroes[name].offline = true end
      end
    end
  end
  WT.last[mine.id], WT.source[mine.id] = time(), sender
  -- Waiting for fresh news before taking a place in it (Fellowship:TakePlace).
  local cb = WT.onNews[mine.id]
  if cb then WT.onNews[mine.id] = nil; cb(mine, sender) end
  if not F:Get(mine.id) or mine.members[ns.Me()] then
    if ns.Window then ns.Window:RefreshSoon() end
    return
  end
  -- A chapter opened while you play another character: time to switch back?
  local after = J:CurrentIndex(mine)
  if after > before then
    local owner
    for _, t in ipairs(WT:Targets()) do if t.f.id == mine.id then owner = t.key end end
    local ch = mine.journey.chapters[after]
    ns:Toast(nil, L.WATCH_TOAST:format(ns.Short(owner or sender), mine.name),
      ch and L.WATCH_TOAST_TEXT:format(J.Roman(after), ch.name) or L.BN_JOURNEY_DONE)
  end
  if ns.Window then ns.Window:RefreshSoon() end
end)

ns:On("LOGIN", function()
  C_Timer.After(20, function() WT:Poll() end)
  C_Timer.NewTicker(WT.POLL, function() WT:Poll() end)
  C_Timer.NewTicker(WT.LIVE, function()
    if WT.active and WT.fid and ns.Window and ns.Window:IsOpen() then WT:Poll(WT.fid) end
  end)
end)
